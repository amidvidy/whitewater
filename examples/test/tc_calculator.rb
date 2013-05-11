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

end
