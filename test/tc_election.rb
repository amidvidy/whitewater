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
      ss.update_term <= [[0]]
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

  # Two servers start_election for the same term (concurrently)
  def test_multiple_candidates
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

    
    # this should timeout because s2 will recieve no response from election_outcome
    assert_raise(SoftTimeout::Error) do
      SoftTimeout.timeout(2) do
        acks1 = s1.sync_callback(:start_election, [['127.0.0.1:54321', 1, nil, nil]], :election_outcome)
        acks2 = s2.sync_callback(:start_election, [['127.0.0.1:54322', 1, nil, nil]], :election_outcome)
      end
    end

    s1.stop
    s2.stop
    s3.stop
    s4.stop
    s5.stop(true, true)

  end
  
  # Multiple sequential elections
  def test_sequential_elections
    puts "test_sequential_elections"
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

    # run 2 elections synchronously, first s1 is leader
    # then s2 is elected afterwards

    s1.sync_do do
      s1.start_election <+ [['127.0.0.1:54321', 1, nil, nil]]
      s1.election_outcome do |eo|
        assert_equal([[1]], eo.term)
      end
    end

    s2.sync_do do
      s2.start_election <+ [['127.0.0.1:54322', 2, nil, nil]]
      s2.election_outcome do |eo|
        assert_equal([[2]], eo.term)
      end
    end

    s1.stop
    s2.stop
    s3.stop
    s4.stop
    s5.stop(true, true)

  end
end

class SoftTimeout
  class Error < Timeout::Error; end

  def self.timeout(t = 10)
    thread = Thread.current
    mutex = Mutex.new
    timeout = Thread.new do
      sleep t
      mutex.synchronize { thread.raise Error, "Timeout after #{t} seconds" }
    end
    v = nil
    begin
      v = yield
    ensure
      mutex.synchronize { timeout.kill }
    end
    v
  end
end
