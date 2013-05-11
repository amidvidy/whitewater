require 'rubygems'
require 'bud'
require 'test/unit'
require '../src/orderedstatemachine'

class OrderedStateMachineBloom
	include Bud
	include OrderedStateMachine
end

class TestOrderedStateMachine < Test::Unit::TestCase

	def setup
		@osm = OrderedStateMachineBloom.new
		@osm.run_bg
	end

	def teardown
		@osm.stop true
	end

  def test_sanity
    @osm.execute_command <+ [[0, ["SET", 10]]]
    @osm.tick
    assert_equal [[0, 10]], @osm.delta(:execute_command_resp)
  end

  def test_ordered
    @osm.execute_command <+ [[0, ["SET", 10]], 
                             [1, ["DIV", 5]], 
                             [2, ["SUB", 12]], 
                             [3, ["DIV", -5]], 
                             [4, ["ADD", 7]]]
    @osm.tick
    assert_equal [[0, 10]], @osm.delta(:execute_command_resp)
    @osm.tick
    assert_equal [[1, 2]], @osm.delta(:execute_command_resp)
    @osm.tick
    assert_equal [[2, -10]], @osm.delta(:execute_command_resp)
    @osm.tick
    assert_equal [[3, 2]], @osm.delta(:execute_command_resp)
    @osm.tick
    assert_equal [[4, 9]], @osm.delta(:execute_command_resp)
  end

  def test_unordered
    @osm.execute_command <+ [[0, ["SET", 10]], 
                             [3, ["DIV", -5]], 
                             [2, ["SUB", 12]], 
                             [1, ["DIV", 5]], 
                             [4, ["ADD", 7]]]
    @osm.tick
    assert_equal [[0, 10]], @osm.delta(:execute_command_resp)
    @osm.tick
    assert_equal [[1, 2]], @osm.delta(:execute_command_resp)
    @osm.tick
    assert_equal [[2, -10]], @osm.delta(:execute_command_resp)
    @osm.tick
    assert_equal [[3, 2]], @osm.delta(:execute_command_resp)
    @osm.tick
    assert_equal [[4, 9]], @osm.delta(:execute_command_resp)
  end


end
