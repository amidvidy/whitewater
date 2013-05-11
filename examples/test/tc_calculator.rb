require 'rubygems'
require 'bud'
require 'test/unit'
require '../src/calculator.rb'

class CalculatorBloom
	include Bud
	include Calculator
end

class TestCalculator < Test::Unit::TestCase

	def setup
		@calc = CalculatorBloom.new
		@calc.run_bg
	end

	def teardown
		@calc.stop true
	end

  def test_sanity
    assert_equal [[10]], @calc.sync_callback(:execute_command, [[["SET", 10]]], :execute_command_resp)
  end

  def test_ordered
    assert_equal [[10]], @calc.sync_callback(:execute_command, [[["ADD", 10]]], :execute_command_resp)
    assert_equal [[5]],  @calc.sync_callback(:execute_command, [[["DIV", 2]]], :execute_command_resp)
    assert_equal [[2]],  @calc.sync_callback(:execute_command, [[["SUB", 3]]], :execute_command_resp)
  end

end
