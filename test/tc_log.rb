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

    @replicas.map(&:tick)
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

  def test_simple
    assert_equal [[0, ["ADD", 10], 10]], @s1.sync_callback(:execute_command, [[0, ["ADD", 10]]], :execute_command_resp)
    assert_equal [[1, ["DIV", 2], 5]], @s1.sync_callback(:execute_command, [[1, ["DIV", 2]]], :execute_command_resp)
    assert_equal [[2, ["SUB", 3], 2]], @s1.sync_callback(:execute_command, [[2, ["SUB", 3]]], :execute_command_resp)
  end

  def test_one_stale_log
    @s2.log <+ [[10, 0, {"reqid"=> 5, "command"=>["MUL", 10]}]]
    @s2.log <+ [[10, 1, {"reqid"=> 6, "command"=>["ADD", 3]}]]
    assert_equal [[0, ["ADD", 10], 10]], @s1.sync_callback(:execute_command, [[0, ["ADD", 10]]], :execute_command_resp)
    assert_equal [[1, ["DIV", 2], 5]], @s1.sync_callback(:execute_command, [[1, ["DIV", 2]]], :execute_command_resp)
    assert_equal [[2, ["SUB", 3], 2]], @s1.sync_callback(:execute_command, [[2, ["SUB", 3]]], :execute_command_resp)
    assert_equal @s1.delta(:log), @s2.delta(:log)
  end

  def test_multiple_stale_log
    @s2.log <+ [[10, 0, {"reqid"=> 5, "command"=>["MUL", 10]}]]
    @s2.log <+ [[10, 1, {"reqid"=> 6, "command"=>["ADD", 3]}]]
    @s3.log <+ [[10, 2, {"reqid"=> 5, "command"=>["MUL", 10]}]]
    @s3.log <+ [[10, 3, {"reqid"=> 6, "command"=>["ADD", 3]}]]
    @s4.log <+ [[10, 4, {"reqid"=> 5, "command"=>["MUL", 10]}]]
    @s4.log <+ [[10, 5, {"reqid"=> 6, "command"=>["ADD", 3]}]]
    @s5.log <+ [[10, 6, {"reqid"=> 5, "command"=>["MUL", 10]}]]
    @s5.log <+ [[10, 7, {"reqid"=> 6, "command"=>["ADD", 3]}]]
    @s5.log <+ [[10, 8, {"reqid"=> 5, "command"=>["MUL", 10]}]]
    @s3.log <+ [[10, 9, {"reqid"=> 6, "command"=>["ADD", 3]}]]
    assert_equal [[0, ["ADD", 10], 10]], @s1.sync_callback(:execute_command, [[0, ["ADD", 10]]], :execute_command_resp)
    assert_equal [[1, ["DIV", 2], 5]], @s1.sync_callback(:execute_command, [[1, ["DIV", 2]]], :execute_command_resp)
    assert_equal [[2, ["SUB", 3], 2]], @s1.sync_callback(:execute_command, [[2, ["SUB", 3]]], :execute_command_resp)
    assert_equal @s1.delta(:log), @s2.delta(:log)
    assert_equal @s1.delta(:log), @s3.delta(:log)
    assert_equal @s1.delta(:log), @s4.delta(:log)
    assert_equal @s1.delta(:log), @s5.delta(:log)
  end

  def test_one_dead_server
    @s2.stop
    assert_equal [[0, ["ADD", 10], 10]], @s1.sync_callback(:execute_command, [[0, ["ADD", 10]]], :execute_command_resp)
    assert_equal [[1, ["DIV", 2], 5]], @s1.sync_callback(:execute_command, [[1, ["DIV", 2]]], :execute_command_resp)
    assert_equal [[2, ["SUB", 3], 2]], @s1.sync_callback(:execute_command, [[2, ["SUB", 3]]], :execute_command_resp)
    @s2.start
    20.times {@replicas.map(&:tick)}
    assert_equal @s1.delta(:log), @s2.delta(:log)
  end

  def test_one_dead_server_after_command
    assert_equal [[0, ["ADD", 10], 10]], @s1.sync_callback(:execute_command, [[0, ["ADD", 10]]], :execute_command_resp)
    @s3.stop
    assert_equal [[1, ["DIV", 2], 5]], @s1.sync_callback(:execute_command, [[1, ["DIV", 2]]], :execute_command_resp)
    assert_equal [[2, ["SUB", 3], 2]], @s1.sync_callback(:execute_command, [[2, ["SUB", 3]]], :execute_command_resp)

    @s3.start
    20.times {@replicas.map(&:tick)}
    assert_equal @s1.delta(:log), @s3.delta(:log)
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
