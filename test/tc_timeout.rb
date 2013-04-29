require 'rubygems'
require 'bud'
require 'test/unit'
require '../src/timeout'

class TestTimeout < Test::Unit::TestCase

  MIN_TIMEOUT = 0.150 # 150ms
  MAX_TIMEOUT = 0.300 # 300ms

  class TimeoutBloom
    include Bud
    include UniformlyDistributedTimeout

    bootstrap do
      interval <= [[MIN_TIMEOUT, MAX_TIMEOUT]]
    end
  end

  # basic sanity test
  def test_timeout
    timer = TimeoutBloom.new
    start_time = Time.new
    timer.sync_callback(:snooze, [[:im_tired]], :alarm)
    stop_time = Time.new
    assert(stop_time - start_time >= MIN_TIMEOUT, "timeout was too short")
    assert(stop_time - start_time <= MAX_TIMEOUT, "timeout was too long")
  end
end
