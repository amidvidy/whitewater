require 'rubygems'
require 'bud'

# Abstract single-site state machine protocol.
# Implement this protocol with your application-specific state machine
module StateMachineProto
  state do
    interface input, :execute_command, [:command]
    interface output, :execute_command_resp, [:new_state]
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
    table :currently_executing, [] => [:command_index, :command]
    lmax :current_index

    scratch :ready, execute_command.schema
    scratch :finished, [:command_index, :command, :new_state]
  end

  bootstrap do
    current_index <= Bud::MaxLattice(0)
  end

  bloom :enqueue_commands do
    # Buffer all commands into uncomitted
    uncomitted <= execute_command 
  end

  bloom :execute_ordered do
    # A command is ready if its index is the current index to execute
    ready <= (uncomitted * current_index).pairs do |u, ci|
      u if ci.reveal == u.command_index and currently_executing.length == 0
    end

    # Update the current index
    current_index <+ ready {|r| Bud::MaxLattice.new(r.index + 1)}

    # Execute the ready commands in the StateMachine
    sm.execute_command <+ ready  

    # Remove now commited entries from uncomitted
    uncomitted <- ready
    currently_executing <+ ready
  end

  bloom :finish_commands do
    
    # Place responses from StateMachine into finished scratch
    finished <= (currently_executing * sm.execute_command_resp).pairs do |ce, ecr|
      [ce.command_index, ce.command, ecr.new_state]
    end

    # Delete finished commands from currently_executing
    currently_executing <- finished {|f| [f.command_index, f.command]}

    # Once StateMachine executes, respond with the new state
    execute_command_resp <= finished {|f| [f.command_index, f.new_state]}
  end

end
