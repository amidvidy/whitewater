require 'rubygems'
require 'bud'
require '../lib/votecounter'
require '../src/serverstate'

module LeaderElectionProto
  state do
    interface input, :start_election, [:candidate_id, :term, :last_log_index, :last_log_term]
    interface output, :election_outcome, [:term]
  end
end

module LeaderElectionImpl
  include LeaderElectionProto
  # This will be included in raft_server
  import ServerStateImpl => :ss
  import VoteCounterImpl => :vc

  state do
    # Channels to pipe requests and responses among the servers
    channel :vote_request_chan, [:@dest, :candidate_id, :term, :last_log_index, :last_log_term]
    channel :vote_response_chan, [:@candidate_id, :from, :term, :vote_granted]

    scratch :vote_buffer, vote_response_chan.schema
  end

  bloom :start_elections do
    # When an election is started, we send a RequestVoteRPC out to each
    # member of the cluster (including ourselves)

    vote_request_chan <~ (start_election * ss.members).pairs do |se, m|
      [m.host, ip_port, se.term, se.last_log_index, se.last_log_term]
    end
  end

  bloom :cast_vote do
    # We cast a vote only if we have not voted for this term and
    # the requester's term is at least the same as ours
    vote_buffer <= (vote_request_chan * ss.max_term_voted * ss.current_term).combos do |req, maxterm, currterm|
      if maxterm.max_term < currterm.term and currterm.term <= req.term
        [req.candidate_id, ip_port, req.term, true]
      else
        [req.candidate_id, ip_port, currterm.term, false]
      end
    end
    # Send back the vote response to the requestor
    vote_response_chan <~ vote_buffer
    # Update current term if it is higher, lattice logic takes
    # care of the messy details here
    ss.update_term <= vote_buffer {|vote| [vote.term]}
    # Update our last term voted
    ss.update_max_term_voted <= vote_buffer {|vote| [vote.term]}
  end

  bloom :count_votes do
    # Starts a vote counter and tally up all the "yes" votes we get
    vc.start_vote <= start_election {|se| [se.term, (ss.members.length / 2) + 1]}
    # count up the votes that were granted
    vc.submit_ballot <= vote_response_chan do |vr|
      [vr.from, vr.term] if vr.vote_granted
    end
    # Update current term if it is higher, lattice logic takes
    # care of the messy details here. If we actually receive a
    # response with a higher term, we won't win the election anyways
    ss.update_term <= vote_response_chan {|resp| [resp.term]}
    # Send vote result alarm if we won, otherwise election_outcome will be empty
    election_outcome <= vc.outcome
  end
end
