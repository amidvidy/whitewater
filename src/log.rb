require 'rubygems'
require 'bud'
require '../lib/votecounter'
require '../src/serverstate'

# Abstract single-site state machine protocol.
module StateMachineProto
  state do
    interface input, :execute_command, [:command]
    interface output, :execute_command_resp, [:command, :new_state]
  end
end

# Replicated state machine protocol.
module ReplicatedStateMachineProto
  state do
    interface input, :execute_command, [:reqid] => [:command]
    interface input, :execute_command_resp [:reqid] => [:command, :new_state]
  end
end

module RaftLog
  include ReplicatedStateMachineProto
  include ServerStateImpl
  import VoteCounterImpl => :vc
  import StateMachineProto => :state_machine


  state do
    channel :append_entries_request_chan, [:@dest, :leader_id, :prev_log_index, :prev_log_term, :entries, :commit_index]
    channel :append_entries_response_chan, [:@dest, :candidate_id, :term, :success]

    table :log, [:term, :index] => [:command]
    table :next_indices, [:client_id] => [:next_index]

    lmax :max_index_comitted

    scratch :prev_index_temp, [:client_id] => [:term, :index]
    scratch :highest_log_entry, log.schema
    scratch :tracked_members, [:client_id]
    scratch :untracked_members, [:client_id]
  end

  # When a leader first comes into power it initializes all
  # next_index values to the index just after the last one in its log
  bloom :bootstrap_leader do
    # get the highest log entry in the log
    highest_log_entry <= log.argmax([:term, :index, :command], :index)

    # figure out which members have uninitialized next_index entries
    tracked_members <= next_indices {|ni| [ni.index]}
    untracked_members <= current_members.notin(tracked_members, :host => :client_id)

    # leader initializes next_index values
    next_indices <= (current_role * untracked_members * highest_log_entry).combos do |cr, um, hle|
      [um.client_id, hle.index] if cr.role == [:LEADER]
    end
  end

  # Clear out next index values if you are not a leader so they get reinitialized if you
  # become leader again
  bloom :not_leader do
    # please let this work
    next_indices <- (next_indices * current_role).pairs do |ni, cr|
      ni if cr.role != [:LEADER]
    end
  end

  bloom :handle_client_request do
    # the leader appends the command to its log as a new entry
    log <+ (execute_command * current_term * highest_log_entry).combos do |ec, ct, hle|
      [ct.term, hle.index + 1, ec.command]
    end

    # start counting acks for this command
    vc.start_vote <= execute_command {|ec| [ec.reqid, (members.length / 2) + 1]}
  end

  # leader sends out and appendEntriesRPC for all out-of-sync followers on each tick
  bloom :start_append_entries do
    # get the term of the previous log entry to send for each client
    prev_index_temp <= (log * next_indices).pairs do |entry, ni|
      [ni.client_id, entry.term, entry.index] if entry.index == ni.index - 1
    end

    append_entries_request_chan <~ (prev_index_temp * next_indices * log * max_index_comitted)
      .combos(next_indices.next_index => log.index, prev_index_temp.client_id => next_indices.client_id) \
    do |prev, ni, entry, mic|
      [prev.client_id, ip_host, prev.index, prev.term, log.command, mic]
    end
  end

end
