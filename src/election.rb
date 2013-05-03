require 'rubygems'
require 'bud'
require '../lib/votecounter'
require '../lib/membership'
require 'timeout'

module RequestVoteRPC
  include StaticMembership
  state do
    # removed candidateId because implementation does not make use of it
    interface input, :request_vote, [:term]
    interface output, :vote_response, [:host, :term, :voteGranted]

    channel :request_vote_chan, [:@dest, :from, :term]
    channel :vote_response_chan, [:@dest, :from, :term, :voteGranted]

    table :votes_casted, [:term]

    scratch :current_term_temp, [:term]
    scratch :vote_response_temp, vote_response_chan.schema
  end

  bloom do
    # plumb start_vote to all members via request_vote_chan
    request_vote_chan <~ (member * request_vote).pairs do |m, s|
      [m.host, ip_port] + s.to_a
    end

    # vote for the candidate if have not voted in given term and myterm <= candidate term
    current_term_temp <= member { |m| [m.term] if m.host == ip_port }
    # stdio <~ current_term_temp.inspected
    stdio <~ request_vote_chan.inspected
    # vote_response_temp <= (request_vote_chan * votes_casted * current_term_temp).outer do |vch, vca, ctt|
    #   if vca.term == [nil] and (tt.term <= vch.term)
    #     [vch.from, vch.dest, m.term, true]
    #   else
    #     [vch.from, vch.dest, m.term, false]
    #   end
    # end
    vote_response_temp <= (request_vote_chan * current_term_temp).pairs do |r, c|
      # if votes_casted.term == [nil]
      #   [r.from, r.dest, c.term, true]
      # else
        [r.from, r.dest, r.term, true]
      # end
    end

    vote_response_chan <~ vote_response_temp
    # update table with new vote
    votes_casted <= vote_response_temp {|vrt| [vrt.term]}

    # output the result of the channel
    vote_response <= vote_response_chan {|vrc| [vrc.from, vrc.term, vrc.voteGranted]}
    stdio <~ vote_response.inspected
  end
end

module LeaderElection
  include RequestVoteRPC
  import VoteCounterImpl => :vc
  state do
    interface input, :start_election, [:term]
    # returns term ONLY if candidate won election.
    interface output, :outcome, [:term]
  end

  bloom do
    # plumb start_election to request vote
    # update_term <= [[ip_port, start_election.term]]
    # stdio <~ update_term.inspected
    request_vote <= start_election
    vc.start_vote <= start_election { |se| [se.term, (member.length / 2).floor + 1] }

    vc.submit_ballot <= vote_response do |vr|
      if vr.voteGranted == true
        [vr.host, vr.term]
      end
    end

    outcome <= vc.outcome
  end

end
