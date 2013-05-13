require 'rubygems'
require 'bud'
require 'test/unit'
require '../src/log'

$IP = '127.0.0.1'
$PORTS = (54321..54325)

class TestLog < Test::Unit::TestCase
  def setup
    @replicas = $PORTS.map {|p| Log.new(:port => p)}
    @replicas.map(&:run_bg)
    @s1, @s2, @s3, @s4, @s5 = @replicas

    @s1.update_role <+ [[:LEADER]]
    @s2.update_role <+ [[:FOLLOWER]]
    @s3.update_role <+ [[:FOLLOWER]]
    @s4.update_role <+ [[:FOLLOWER]]
    @s5.update_role <+ [[:FOLLOWER]]
  end

  def teardown
    @s1.stop
    @s2.stop
    @s3.stop
    @s4.stop
    @s5.stop true
  end

  def test_sanity
    resp = @s1.sync_callback(:execute_command, [[0, ["SET", 10]]], :execute_command_resp)
    assert_equal [[0, ["SET", 10], 10]], resp
  end
end

class Log
  include Bud
  include RaftLog

  bootstrap do
    members <= $PORTS.map {|p| ["#{$IP}:#{p}"]}
    update_term <= [[0]]
  end
end
