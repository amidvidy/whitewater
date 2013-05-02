require 'bud'
require 'test/unit'
require '../src/timeout'

class TestTimeout < Test::Unit::TestCase

  MIN_TIMEOUT = 0.250 # 250ms
  MAX_TIMEOUT = 0.500 # 500ms
  class TimeoutBloom
    include Bud
    include UniformlyDistributedTimeout

    bootstrap do
      config <= [[MIN_TIMEOUT, MAX_TIMEOUT]]
    end
  end

  # basic sanity test
  def test_timeout
    timer = TimeoutBloom.new
    timer.run_bg
    10.times do
      start_time = Time.new
      timer.sync_callback(:snooze, [["my_id"]], :alarm)
      stop_time = Time.new
      assert(stop_time - start_time >= MIN_TIMEOUT, "timeout was too short")
      assert(stop_time - start_time <= MAX_TIMEOUT, "timeout was too long")
    end
  end
end
