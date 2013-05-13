# log.rb

## *module*: StronglyConsistentDistributedStateMachineProto

An abstract protocol representing a strongly consistent distributed state machine.

```ruby
interface input, :execute_command, [:reqid] => [:command]
interface output, :execute_command_resp, [:reqid] => [:command, :new_state]
```

### *input*: execute\_command

- `reqid`: A unique numeric identifier for this command
- `command`: The actual command to apply to the state machine

### *output*: execute\_command\_resp

- `reqid`: Same value passed to `execute_command`
- `command`: The command that was successfully applied to the state machine
- `new_state`: The resulting state of the state machine after the command was applied

## *module*: RaftLog

A concrete distributed state machine protocol. Uses the Raft log replication algorithm to coordinate state between replicas.


