# Abstract single-site state machine protocol.
# Implement this protocol with your application-specific state machine
module StateMachineProto
  state do
    interface input, :execute_command, [:command]
    interface output, :execute_command_resp, [:new_state]
  end
end
