require 'rubygems'
require 'bud'
require '../lib/votecounter'
require '../lib/reliable'
require '../src/serverstate'
require '../src/orderedstatemachine'

# Quite the mouthful, eh?
module StronglyConsistentDistributedStateMachineProto
  state do
    interface input, :execute_command, [:reqid] => [:command]
    interface output, :execute_command_resp, [:reqid] => [:command, :new_state]
  end
end

# TODO:
#   - automatically send heartbeats
#   - handle server status changes

# yo, so I heard you like logging...
module RaftLogLogger
  bloom :log_to_stdio do
    #stdio <~ current_role {|cr| ["server #{ip_port}-@#{budtime}: current_role #{cr}"]}
    #stdio <~ highest_log_entry {|hle| [["server #{ip_port}-@#{budtime}: highest_log_entry #{hle}"]]}
    stdio <~ sm.execute_command {|ec| [["server #{ip_port}-@#{budtime}: sm.execute_command #{ec}"]]}
    stdio <~ next_indices {|ni| [["server #{ip_port}-@#{budtime}: next_indices #{ni}"]]}
    stdio <~ new_entries {|ne| [["server #{ip_port}-@#{budtime}: new_entries #{ne}}"]]}
    stdio <~ to_commit {|tc| [["server #{ip_port}-@#{budtime}: to_commit #{tc}}"]]}
    #stdio <~ append_entry_valid {|aec| [["server #{ip_port}-@#{budtime} append_entry_valid: #{aec}"]]}
    #stdio <~ append_entry_success {|aec| [["server #{ip_port}-@#{budtime} append_entry_success: #{aec}"]]}
    #stdio <~ log {|l| [["server #{ip_port}-@#{budtime}: log #{l}"]]}
    stdio <~ active_commands {|ac| [["server #{ip_port}-@#{budtime}: active_commands #{ac}"]]}
    #stdio <~ vc.submit_ballot {|vc| [["server #{ip_port}-@#{budtime}: vc.submit_ballot #{vc}"]]}
    #stdio <~ rd.pipe_in {|pi| [["server #{ip_port}-@#{budtime}: rd.pipe_in #{pi}"]]}
  end
end

module RaftLog
  include StronglyConsistentDistributedStateMachineProto
  include ServerStateImpl
  #include RaftLogLogger

  import ReliableDelivery => :rd
  import VoteCounterImpl => :vc
  import OrderedStateMachine => :sm

  state do
    # the log
    table :log, [:term, :index] => [:entry]
    # entries to the log that have been committed
    table :committed_entries, [:term, :index] => []

    table :active_commands, [:reqid] => [:log_index, :command]

    # the index of the highest log entry committed so far
    lmax :max_index_committed

    scratch :new_entries, log.schema
    # entries ready to be committed on this tick
    scratch :to_commit, log.schema

    # the next log index to send to each follower
    table :next_indices, [:client_id] => [:next_index]

    # scratches for master logic
    scratch :highest_log_entry, log.schema
    scratch :tracked_members, [:client_id]
    scratch :untracked_members, [:client_id]
    scratch :finished_commands, [:reqid] => [:log_index, :command, :new_state]

    # scratches for follower logic
    scratch :append_entry_valid, [:leader_id, :term, :prev_log_index, :prev_log_term, :entry, :commit_index]
    scratch :append_entry_success, [:leader_id, :entry, :prev_term, :prev_index, :commit_index, :success]
    scratch :uncommitted, log.schema
  end

  bootstrap do
    # log needs dummy entry
    log <= [[0, -1, nil]]
  end

  # when log entries are committed, they can be applied to the state machine
  bloom :apply_committed_to_state_machine do
    # find entries ready to commit that have not yet been committed
    uncommitted <= log.notin(committed_entries, :term => :term, :index => :index)
    to_commit <= uncommitted do |u|
      u if u.index <= max_index_committed.reveal and u.index >= 0
    end

    # commit them
    committed_entries <+ to_commit {|tc| [tc.term, tc.index]}
    sm.execute_command <= to_commit do |tc| 
      [tc.index, tc.entry["command"]]
    end
  end

  # LEADER RULES

  # When a leader first comes into power it initializes all
  # next_index values to the index just after the last one in its log
  bloom :bootstrap_leader do
    # get the highest log entry in the log
    highest_log_entry <= log.argmax([], :index)

    # figure out which members have uninitialized next_index entries
    tracked_members <= next_indices {|ni| [ni.client_id]}
    temp :untracked <= current_members.notin(tracked_members)
    untracked_members <= untracked do |ut|
      # someone is untracked if they are not this node and not currently tracked
      ut if ut.host != ip_port
    end

    # leader initializes next_index values
    next_indices <= (current_role * untracked_members * highest_log_entry).combos do |cr, um, hle|
      [um.client_id, hle.index] if cr.role == :LEADER and hle.index >= 0
    end
  end

  bloom :handle_client_request do
    # the leader appends the command to its log as a new entry
    new_entries <= (execute_command * current_term * highest_log_entry).combos do |ec, ct, hle|
      [ct.term, hle.index + 1, {
        "reqid" => ec.reqid,
        "command" => ec.command
      }]
    end

    active_commands <= new_entries {|ne| [ne.entry["reqid"], ne.index, ne.entry["command"]]}

    # add new entries to log
    log <+ new_entries

    # start counting acks for this command
    vc.start_vote <= new_entries {|ne| [ne.entry["reqid"], (members.length / 2) + 1]}
  end

  # leader sends out and appendEntriesRPC for all out-of-sync followers on each tick
  bloom :start_append_entries do
    # this is extremely inefficient (must compute the cross product of all log entries
    # but I'm not sure there is a better way to do this in Bloom
    rd.pipe_in <= (next_indices * log * log * current_term).combos do |ni, cur_entry, prev_entry, currterm|
      if prev_entry.index == ni.next_index - 1 and cur_entry.index == ni.next_index
        # payload is the actual AppendEntriesRPC
        [ni.client_id, ip_port, cur_entry.entry["reqid"], {
          "term" => currterm.term,
          "leader_id" => ip_port, # still unused
          "prev_log_index" => prev_entry.index,
          "prev_log_term" => prev_entry.term,
          "entry" => cur_entry.entry,
          "commit_index" => max_index_committed
        }]
      end
    end
  end

  bloom :finish_append_entries do
    # if a follower successfully acked this log entry, send it the next one, otherwise, send it the
    # previous one
    next_indices <+- (rd.pipe_out * next_indices).pairs(:src => :client_id) do |aer, ni|
      if aer.payload["log_index"] == ni.next_index
        if aer.payload["success"]
          [ni.client_id, ni.next_index + 1]
        else
          [ni.client_id, ni.next_index - 1]
        end
      end
    end

    # TODO update term and step down if response term is higher

    # count up the successful votes so we can commit
    vc.submit_ballot <= (rd.pipe_out * next_indices).pairs(:src => :client_id) do |aer, ni|
      # aer.ident is the reqid
      [ni.client_id, aer.ident] if aer.payload["success"]
    end
  end

  bloom :commit do
    # a command can be committed when a majority of followers have appended it to their logs
    max_index_committed <= (vc.outcome * active_commands).rights(:prop => :reqid) do |command|
      #puts "THIS COMMAND IS BEING COMMITED #{command}"
      Bud::MaxLattice.new(command.log_index)
    end
  end

  bloom :respond_to_client do
    finished_commands <= (active_commands * sm.execute_command_resp).pairs(:log_index => :command_index) do |ac, ecr|
      [ac.reqid, ecr.command_index, ac.command, ecr.new_state]
    end
    # remove finished commands from active_commands
    active_commands <- finished_commands {|fc| [fc.reqid, fc.log_index, fc.command]}
    # send response to client
    execute_command_resp <= finished_commands {|fc| [fc.reqid, fc.command, fc.new_state]}
  end

  # FOLLOWER RULES

  # Clear out next index values if you are not a leader so they get reinitialized if you
  # become leader again
  bloom :not_leader do
    # please let this work
    next_indices <- (next_indices * current_role).pairs do |ni, cr|
      ni if cr.role != :LEADER
    end
  end

  bloom :handle_append_entries do
    # update term if the requestors term is higher than ours, lattice logic handles the details
    update_term <+ rd.pipe_out do |req| 
      [req.payload["term"]]
    end
    # these are the RPCs that are not from a deposed leader (term < current_term)

    append_entry_valid <= (rd.pipe_out * current_term * current_role).combos do |message, currterm, curr_role|
      unless message.payload["term"] < currterm.term or curr_role.role == :LEADER
        #puts "SHITS PRINTING OUT #{message.payload} and #{ip_port} AND CURRENT ROLE: #{curr_role.role}"
        [
          message.payload["leader_id"],
          message.payload["term"],
          message.payload["prev_log_index"],
          message.payload["prev_log_term"],
          message.payload["entry"],
          message.payload["commit_index"].reveal
        ]
      end
    end

    append_entry_success <= (log * append_entry_valid)
    .pairs(:index => :prev_log_index, :term => :prev_log_term) do |entry, append_req|
      [
        append_req.leader_id,
        append_req.entry,
        append_req.prev_log_term,
        append_req.prev_log_index,
        append_req.commit_index,
        true
      ]
    end

    # TODO - send failure responses

    # delete any conflicting entries
    log <- (log * append_entry_success).pairs do |entry, as|
      entry if entry.index > as.prev_index or entry.term > as.prev_term
    end

    # add new entry
    log <+ (append_entry_success * current_term).pairs do |as, currterm|
      [currterm.term, as.prev_index + 1, as.entry]
    end

    # update the max entry that we can commit
    max_index_committed <= append_entry_success do |as|
      Bud::MaxLattice.new(as.commit_index)
    end

    # send response back to leader
    rd.pipe_in <= (append_entry_success * current_term).pairs do |as, currterm|
      [as.leader_id, ip_port, as.entry["reqid"], {
        "term" => currterm.term,
        "success" => as.success,
        "log_index" => as.prev_index
      }]
    end
  end
end
