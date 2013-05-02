require 'rubygems'
require 'bud'

# The Timeout protocol.
module TimeoutProto
  state do
    # must be set once, at bootstrap time
    interface input, :config, [] => [:min_timeout, :max_timeout]
    # Resets the timeout. ID should be a unique value specified by the client,
    # such as ip_port
    interface input, :snooze, [:id]
    # Signals that a timeout has been triggered.
    interface output, :alarm, [:id]
  end
end

module UniformlyDistributedTimeout
  include TimeoutProto

  # Internal clock will be triggered every 50ms
  TIMER_INTERVAL = 0.05

  state do
    periodic :timer, TIMER_INTERVAL
    table :timer_state, [:id] => [:start_tm, :time_out]
    table :conf, config.schema
  end

  bloom :timeouts do

    conf <= config

    # on snooze, set a new timeout
    timer_state <+- (timer_state * timer * snooze * conf).combos(timer_state.id => snooze.id) do |ts, t, s, c|
      [ts.id, t.value.to_f, Random.new.rand(c.min_timeout..c.max_timeout)]
    end

    temp :triggered <= (timer_state * timer).combos do |state, time|
      if time.val.to_f - state.start_tm > state.time_out
          [state.id, state.start_tm, state.time_out]
      end
    end

    timer_state <- triggered
    alarm <= triggered {|t| [t.id]}
  end
end
