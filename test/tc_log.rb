require 'rubygems'
require 'bud'
require 'test/unit'
require '../src/log'

$IP = '127.0.0.1'
$PORTS = (54321..54325)

class TestLog < Test::Unit::TestCase
  def setup
    @replicas = $PORTS.map {|p| Log.new(:port => p)}
    @replicas.map(&:run_bg)
    @s1, @s2, @s3, @s4, @s5 = @replicas
  end

  def teardown
    @s1.stop
    @s2.stop
    @s3.stop
    @s4.stop
    @s5.stop true
  end
end

class Log
  include Bud
  include RaftLog

  bootstrap do
    members <= $PORTS.map {|p| ["#{$IP}:#{p}"]}
    update_term <= [[0]]
  end
end
