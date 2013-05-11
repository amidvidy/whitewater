require 'bud'
require 'test/unit'
require '../src/timeout'

class TestTimeout < Test::Unit::TestCase

  MIN_TIMEOUT = 0.25 # 250ms
  MAX_TIMEOUT = 0.5  # 500ms

  def setup
    @timer = TimeoutBloom.new
    @timer.run_bg
  end

  def teardown
    @timer.stop true
  end

  # basic sanity test
  def test_timeout
    10.times do
      start_time = Time.new
      @timer.sync_callback :snooze, [["my_id"]], :alarm
      stop_time = Time.new
      
      assert stop_time - start_time >= MIN_TIMEOUT, "timeout was too short"
      assert stop_time - start_time <= MAX_TIMEOUT, "timeout was too long"
    end
  end
end

class TimeoutBloom
  include Bud
  include UniformlyDistributedTimeout

  bootstrap do
    config <= [[TestTimeout::MIN_TIMEOUT, TestTimeout::MAX_TIMEOUT]]
  end
end
