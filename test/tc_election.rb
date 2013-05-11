require 'rubygems'
require 'bud'
require 'test/unit'
require '../src/election'

$IP = '127.0.0.1'
$PORTS = (54321..54325)

class TestElection < Test::Unit::TestCase
  def setup
    @replicas = $PORTS.map { |p| Election.new(:port => p) }
    @replicas.map(&:run_bg)
    @s1, @s2, @s3, @s4, @s5 = @replicas
  end

  def teardown
    @s1.stop
    @s2.stop
    @s3.stop
    @s4.stop
    @s5.stop true
  end

  def test_sanity
    acks = @s1.sync_callback :start_election, [["#{$IP}:54321", 1, nil, nil]], :election_outcome
    assert_equal [[1]], acks
  end

  # Two servers start_election for the same term
  def test_multiple_candidates
    # this should timeout because @s2 will recieve no response from election_outcome
    acks1 = @s1.sync_callback :start_election, [["#{$IP}:54321", 1, nil, nil]], :election_outcome
    assert_equal [[1]], acks1

    assert_raise(SoftTimeout::Error) do
      SoftTimeout.timeout(2) do
        acks2 = @s2.sync_callback :start_election, [["#{$IP}:54322", 1, nil, nil]], :election_outcome
      end
    end
  end
  
  def test_concurrent_candidates
    @s1.start_election <+ [["#{$IP}:54321", 1, nil, nil], ["#{$IP}:54322", 1, nil, nil]]

    begin
      SoftTimeout.timeout(2) { @s1.delta :election_outcome }
    rescue SoftTimeout::Error
      begin
        SoftTimeout.timeout(2) { @s2.delta :election_outcome }
      rescue SoftTimeout::Error
        assert false, "Both Servers Lost the Election"
      end

      assert true
      return
    end

    begin
      SoftTimeout.timeout(2) { @s2.delta :election_outcome }
    rescue SoftTimeout::Error
      assert true
      return
    end

    flunk "Both Servers Won"
  end
  # Multiple sequential elections
  def test_sequential_elections
    # run 2 elections synchronously, first @s1 is leader
    # then @s2 is elected afterwards
    acks = @s1.sync_callback :start_election, [["#{$IP}:54321", 1, nil, nil]], :election_outcome
    assert_equal [[1]], acks

    acks2 = @s2.sync_callback :start_election, [["#{$IP}:54322", 2, nil, nil]], :election_outcome
    assert_equal [[2]], acks2
  end
end

class Election
  include Bud
  include LeaderElectionImpl

  bootstrap do
    members <= $PORTS.map { |p| ["#{$IP}:#{p}"] }
    update_term <= [[0]]
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
