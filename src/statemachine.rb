require 'rubygems'
require 'bud'

# Abstract single-site state machine protocol.
# Implement this protocol with your application-specific state machine
module StateMachineProto
  state do
    interface input, :execute_command, [:reqid] => [:command]
    interface output, :execute_command_resp, [:reqid] => [:command, :new_state]
  end
end

# Wraps the StateMachineProto to handle unordered commands
# replace the StateMachineProto import with your application-specific state machine
module OrderedStateMachine
  import StateMachineProto => :sm

  state do
    interface input, :execute_command, [:command_index] => [:command]
    interface output, :execute_command_resp, [:command_index, :new_state]

    table :uncomitted, execute_command.schema
    lmax :current_index
  end

  bootstrap do
    current_index <= [[Bud::MaxLattice(0)]]
  end

  bloom :execute_ordered do

  end
end
