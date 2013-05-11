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
    5.times { @osm.tick }
    assert_equal [[0, 10]], @osm.delta(:execute_command_resp)
  end

end
