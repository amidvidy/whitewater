# statemachine.rb

## *module*: OrderedStateMachine

Wraps around a simple state machine to handle unordered commands. You can import your own state machine under here to use it.

```ruby
interface input, :execute_command, [:command_index] => [:command]
interface output, :execute_command_resp, [:command_index, :new_state]
```

### *input*: execute_command

- `command_index`: The order of the command to be executed
- `command`: The actual command that is to be executed by the state machine

### *output*: execute_command_resp
- `command_index`: The order of the command that was executed
- `new_state`: The updated state of the state machine, a value

### Additional Info:
### Things OrderedStateMachine does:

-	Buffers all incoming commands and execute them according to their command_index (starting at 0)
