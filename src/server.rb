require 'rubygems'
require 'bud'

require 'timeout.rb'
require 'election.rb'

module RaftServer
  import LeaderElection => :le
  state do
    interface input, :command,
    table :leader, [] => [:host]
  end
end
