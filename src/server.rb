require 'rubygems'
require 'bud'

require 'timeout.rb'
require 'election.rb'

module RaftServer
  import LeaderElection => :le
  import UniformlyDistributedTimeout => :timeout

  state do
    interface input, :command,
    # leader keeps track of who leader is, address corresponds to member.host in StaticMembership
    table :leader, [] => [:host]
    # state is either :LEADER, :FOLLOWER, :CANDIDATE
    table :state, [] => [:status]
  end

  # every server starts up as :FOLLOWER, necessary?
  bootstrap do
    state <= [:FOLLOWER]
  end

end
