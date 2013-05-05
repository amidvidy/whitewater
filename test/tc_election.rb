require 'rubygems'
require 'bud'
require 'test/unit'
require '../src/election'

class TestElection < Test::Unit::TestCase
  class Election
    include Bud
    include LeaderElectionImpl

    bootstrap do
      ss.members <= [
        ['127.0.0.1:54321'],
        ['127.0.0.1:54322'],
        ['127.0.0.1:54323'],
        ['127.0.0.1:54324'],
        ['127.0.0.1:54325']
      ]

    end
  end

  def test_sanity
    s1 = Election.new(:port => 54321)
    s1.run_bg
    s2 = Election.new(:port => 54322)
    s2.run_bg
    s3 = Election.new(:port => 54323)
    s3.run_bg
    s4 = Election.new(:port => 54324)
    s4.run_bg
    s5 = Election.new(:port => 54325)
    s5.run_bg

    acks = s1.sync_callback(:start_election, [['127.0.0.1:54321', 1, nil, nil]], :election_outcome)
    assert_equal([[1]], acks)

    s1.stop
    s2.stop
    s3.stop
    s4.stop
    s5.stop(true, true)
  end
end
