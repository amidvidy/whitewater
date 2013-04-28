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
      interval <= [MIN_TIMEOUT, MAX_TIMEOUT]
    end
  end

  def test_timeout

  end
end
