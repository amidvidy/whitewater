require 'rubygems'
require 'bud'

module LeaderElectionProto
  state do
    interface input, :start_election, [:term, :candidate_id, :last_log_index, :last_log_term]
    interface output, :election_outcome, [:term]
  end
end

module LeaderElectionImpl
  include LeaderElectionProto

  state do
    channel :vote_request_chan, [:@dest, :term, :candidate_id, :last_log_index, :last_log_term]
    channel :vote_response_chan, [:@dest, :from, :term, :vote_granted]
  end

end
