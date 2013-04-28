require 'rubygems'
require 'bud'
require 'random'

module TimeoutProto
  state do
    interface input, :interval, [] => [:minTimeout, :maxTimeout]
    interface input, :snooze, [:ok]
    interface output, :alarm, [:timeout]
  end
end

module UniformlyDistributedTimeout
  include TimeoutProto

  TIMER_INTERVAL = 0.05
  entropy = Random.new

  state do
    periodic :timer, TIMER_INTERVAL
    table :countdown, [] => [:timeRemaining] 
  end
  
  bloom do
  
    # countdown contains the amount of time remaining till the alarm "wakes_up"
    # it is reset to a random timeout if snooze is recieved
    countdown <+- (timer * countdown * interval * snooze).combos do |t, c, i, s|
        if snooze.ok == [nil]
          [countdown.timeRemaining - TIMER_INTERVAL]
        else
          [entropy.rand(i.minTimeout..i.maxTimeout)]
        end
    end
    
    # alarm sends out wake_up calls
    alarm <= countdown { |c| [:wake_up] if c.timeRemaining <= 0 }
    
  end
end
