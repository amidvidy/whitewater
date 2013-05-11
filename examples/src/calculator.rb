require 'rubygems'
require 'bud'
require_relative '../../lib/statemachine'

# Very basic example of a state machine implementation.
# Implements a simple calculator.

# Commands are of the format [OP, ARG]
# Response is the current value of MEM
# Mem is initially 0

# operation:
# SET: MEM = ARG
# ADD: MEM = MEM + ARG
# SUB: MEM = MEM - ARG
# MUL: MEM = MEM * ARG
# DIV: MEM = MEM / ARG

module Calculator
  include StateMachineProto

  state do
    table :mem, [] => [:value]
    scratch :new_mem, [:value]
  end

  bootstrap do
    mem <= [[0.0]]
  end

  bloom do
    new_mem <= (execute_command * mem).pairs do |c, m|
      case c.command[0]
      when "SET"
        [c.command[1].to_f]
      when "ADD"
        [m.value + c.command[1].to_f]
      when "SUB"
        [m.value - c.command[1].to_f]
      when "MUL"
        [m.value * c.command[1].to_f]
      when "DIV"
        [m.value / c.command[1].to_f]
      else
        # ignore
        [m.value]
      end
    end
    mem <+- new_mem
    execute_command_resp <= new_mem
  end
end
