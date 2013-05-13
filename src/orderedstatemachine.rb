require 'rubygems'
require 'bud'
require '../examples/src/calculator'
require '../lib/statemachine'

# Wraps the StateMachineProto to handle unordered commands
# replace the Calculator import with your application-specific state machine
module OrderedStateMachine

  import Calculator => :sm

  state do
    interface input, :execute_command, [:command_index] => [:command]
    interface output, :execute_command_resp, [:command_index, :new_state]

    table :uncommitted, execute_command.schema
    table :currently_executing, [] => [:command_index, :command]
    lmax :current_index
    lmax :current_index_acked

    scratch :ready, execute_command.schema
    scratch :finished, [:command_index, :command, :new_state]
  end

  bootstrap do
    current_index <= Bud::MaxLattice.new(0)
    current_index_acked <= Bud::MaxLattice.new(0)
  end

  bloom :enqueue_commands do
    # Buffer all commands into uncommitted
    uncommitted <= execute_command
  end

  bloom :execute_ordered do
    # A command is ready if its index is the current index to execute
    ready <= uncommitted do |u|
      u if current_index.reveal == u.command_index && current_index.reveal == current_index_acked.reveal
    end

    # Update the current index
    current_index <+ ready {|r| Bud::MaxLattice.new(r.command_index + 1)}

    # Execute the ready commands in the StateMachine
    sm.execute_command <+ ready {|r| [r.command]}

    # Remove now commited entries from uncommitted
    uncommitted <- ready
    currently_executing <+ ready
  end

  bloom :finish_commands do
    # Place responses from StateMachine into finished scratch
    finished <= (currently_executing * sm.execute_command_resp).pairs do |ce, ecr|
      [ce.command_index, ce.command, ecr.new_state]
    end

    current_index_acked <+ finished {|f| Bud::MaxLattice.new(f.command_index + 1)}

    # Delete finished commands from currently_executing
    currently_executing <- finished {|f| [f.command_index, f.command]}

    # Once StateMachine executes, respond with the new state
    execute_command_resp <= finished {|f| [f.command_index, f.new_state]}
  end
end

module OrderedStateMachineLogger
  bloom :print_to_stdio do
    stdio <~ uncommitted {|u| [["@#{budtime}: uncommitted: #{u}"]] }
    stdio <~ currently_executing {|c| [["@#{budtime}: currently_executing: #{c}"]] }
    stdio <~ [["@#{budtime}: currently_executing_length: #{currently_executing.length}"]]
    stdio <~ [["@#{budtime}: current_index: #{current_index.reveal}"]]
    stdio <~ [["@#{budtime}: current_index_acked: #{current_index_acked.reveal}"]]
    stdio <~ ready {|r| [["@#{budtime}: ready: #{r}"]] }
    stdio <~ finished {|f| [["@#{budtime}: finished: #{f}"]] }
    end
end
