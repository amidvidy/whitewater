require 'rubygems'
require 'bud'
require '../lib/votecounter'
require '../lib/membership'
require 'timeout'

module RequestVoteRPC
  include StaticMembership
  state do
    # candidateId is the candidate requesting the vote
    interface input, :request_vote, [:term, :candidateId]
    interface output, :vote_response, [:host, :term, :voteGranted]

    channel :request_vote_chan, [:@dest, :from, :term, :candidateId]
    channel :vote_response_chan, [:@dest, :from, :term, :voteGranted]

    table :votes_casted, [:term]
  end

  bloom do
    # plumb start_vote to all members via vote_chan
    vote_chan <~ (member * request_vote).pairs do |m, s|
      [m.host, ip_port] + s.to_a
    end

    # vote for the candidate if have not voted in given term and myterm <= candidate term
    temp :current_term_temp <= member { |m| [m.term] if m.host == ip_port }
    temp :vote_response_temp <= (request_vote_chan * votes_casted * current_term_temp).outer do |vch, vca, ctt|
      if votes_casted.term == [nil] and (tt.term <= vch.term)
        [vch.from, vch.dest, m.term, true]
      else
        [vch.from, vch.dest, m.term, false]
      end
    end

    vote_response_chan <~ vote_response_temp
    # update table with new vote
    votes_casted <= vote_response_temp {|vrt| [vrt.term]}

    # output the result of the channel
    vote_response <= vote_response_chan {|vrc| [vrc.from, vrc.term, vrc.voteGranted]}
  end
end

module LeaderElection
  include StaticMembership
  import RequestVoteRPC => :rv
  import VoteCounterImpl => :vc
  state do
    interface input, :start_election, [:term, :candidateId]

    # returns term if candidate won election.
    interface output, :outcome, [:term]
  end

  bloom do
    # plumb start_election to request vote
    rv.request_vote <= start_election
    vc.start_vote <= start_election { |se| [se.term, (member.length / 2).floor + 1] }

    vc.submit_ballot <= rv.vote_response do |vr|
      if vr.voteGranted == true
        [vr.host, vr.term]
      end
    end

    outcome <= vc.outcome
  end

end
