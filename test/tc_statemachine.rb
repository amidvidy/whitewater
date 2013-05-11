require 'rubygems'
require 'bud'
require 'test/unit'
require '../src/statemachine'

class StateMachine
	include Bud
	include OrderedStateMachine
end

class TestOrderedStateMachine < Test::Unit::TestCase

	def setup
		@osm = OrderedStateMachine.new
		@osm.run_bg
	end

	def teardown
		@osm.stop true
	end

  def test_sanity
    resp = @osm.sync_callback :execute_command, [[0, ["SET", 10]]], :execute_command_resp
    assert_equal [[0, 10]], resp
  end

end
