require 'rubygems'
require 'bud'
require '../lib/votecounter'
require '../src/serverstate'
require '../src/orderedstatemachine'

# Quite the mouthful, eh?
module StronglyConsistentDistributedStateMachineProto
  state do
    interface input, :execute_command, [:reqid] => [:command]
    interface output, :execute_command_resp [:reqid] => [:command, :new_state]
  end
end

module RaftLog
  include StronglyConsistentDistributedStateMachineProto
  include ServerStateImpl
  import VoteCounterImpl => :vc
  import OrderedStateMachine => :sm


  state do
    channel :append_entries_request_chan, [:@dest, :leader_id, :term, :prev_log_index, :prev_log_term, :entry, :commit_index]
    channel :append_entries_response_chan, [:@dest, :candidate_id, :term, :success]

    # the log
    table :log, [:term, :index] => [:command]
    # entries to the log that have been committed
    table :committed_entries, [:term, :index] => []

    # the index of the highest log entry committed so far
    lmax :max_index_committed
    # entries ready to be committed on this tick
    scratch :to_commit, log.schema

    # the next log index to send to each follower
    table :next_indices, [:client_id] => [:next_index]

    # scratches for master logic
    scratch :highest_log_entry, log.schema
    scratch :tracked_members, [:client_id]
    scratch :untracked_members, [:client_id]

    # scratches for follower logic
    scratch :append_entry_success, [:leader_id, :command, :prev_term, :prev_index, :commit_index, :success]
  end

  # when log entries are committed, they can be applied to the state machine
  bloom :commit_to_state_machine do
    # find entries ready to commit that have not yet been committed
    to_commit <= (committed_entries * log).outer(:term => :term, :index => :index) do |ce, l|
      l if ce == [nil, nil] and l.index <= max_index_comitted.reveal
    end

    # commit them
    committed_entries <+ to_commit {|tc| [tc.term, tc.index]}
    sm.execute_command <= to_commit {|tc| [tc.index, tc.command]}
  end

  # LEADER RULES

  # When a leader first comes into power it initializes all
  # next_index values to the index just after the last one in its log
  bloom :bootstrap_leader do
    # get the highest log entry in the log
    highest_log_entry <= log.argmax([:term, :index, :command], :index)

    # figure out which members have uninitialized next_index entries
    tracked_members <= next_indices {|ni| [ni.client_id]}
    untracked_members <= (tracked_members * current_members).outer(:client_id => :host) do |tm, cm|
      # someone is untracked if they are not this node and not currently tracket
      cm if tm == [nil] and cm.host != ip_port
    end

    # leader initializes next_index values
    next_indices <= (current_role * untracked_members * highest_log_entry).combos do |cr, um, hle|
      [um.client_id, hle.index] if cr.role == [:LEADER]
    end
  end

  bloom :handle_client_request do
    # the leader appends the command to its log as a new entry
    log <+ (execute_command * current_term * highest_log_entry).combos do |ec, ct, hle|
      [ct.term, hle.index + 1, ec.command]
    end

    # start counting acks for this command
    vc.start_vote <= execute_command {|ec| [[ec.reqid, :win], (members.length / 2) + 1]}
    vc.start_vote <= execute_command {|ec| [[ec.reqid, :fail], (members.length / 2) + 1]}
  end

  # leader sends out and appendEntriesRPC for all out-of-sync followers on each tick
  bloom :start_append_entries do
    append_entries_request_chan <~ (next_indices * log * log * current_term).combos \
    do |ni, entry, prev_entry, currterm|
      if prev_entry.index == ni.index - 1 and entry.index == ni.index
      [ni.client_id, ip_host, currterm.term, prev_entry.index, prev_entry.term, entry.command, max_index_committed]
      end
    end
  end




  # FOLLOWER RULES

  # Clear out next index values if you are not a leader so they get reinitialized if you
  # become leader again
  bloom :not_leader do
    # please let this work
    next_indices <- (next_indices * current_role).pairs do |ni, cr|
      ni if cr.role != [:LEADER]
    end
  end

  bloom :handle_append_entries do
    # update term if the requestors term is higher than ours, lattice logic handles the details
    update_term <+ append_entries_request_chan {|req| [req.term]}

    append_entry_success <~ (log * append_entries_request_chan * current_term)
      .outer(:index => :pre_log_index, :term => :prev_log_term) do |entry, append_req, currterm|
      # if we get an appendEntriesRPC from a false leader, ignore it
      unless append_req.term <= currterm.term
        if entry != [nil, nil, nil]
          # if we have a matching previous entry, we can append this log entry
          [append_req.leader_id, append_req.entry, append_req.prev_log_term, append_req.prev_log_index, true]
        else
          # we don't have a matching previous entry, leader will try again with an earlier entry
          [append_req.leader_id, append_req.entry, append_req.prev_log_term, append_req.prev_log_index, false]
        end
      end
    end

    # delete any conflicting entries
    log <- (log * append_entry_success).pairs do |entry, as|
      entry if entry.index > as.prev_index or entry.term > as.prev_term
    end

    # add new entry
    log <+ (append_entry_success * current_term).pairs do |as, currterm|
      [currterm.term, as.prev_index + 1, as.command]
    end

    # update the max entry that we can commit
    max_index_committed <= append_entry_success {|as| [as.commit_index]}

    # send response back to leader
    append_entries_response_chan <~ (append_entry_success * current_term).pairs do |as, currterm|
      [as.leader_id, ip_port, currterm.term, as.success]
    end
  end

end
