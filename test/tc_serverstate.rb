require 'rubygems'
require 'bud'
require 'test/unit'
require '../src/serverstate'

class ServerStateBloom
	include Bud
	include ServerStateImpl

	bootstrap do
		term <= Bud::MaxLattice.new(-1)
		term_voted <= Bud::MaxLattice.new(-1)
		role <= [[:FOLLOWER]]
		members <= [["alice"], ["bob"], ["carol"]]
	end
end

class TestServerState < Test::Unit::TestCase
	def setup
		@state = ServerStateBloom.new
		@state.run_bg
	end

	def teardown
		@state.stop true
	end

	def test_sanity
		assert_equal [[-1]], @state.delta(:current_term)
		assert_equal [[-1]], @state.delta(:max_term_voted)
		assert_equal [[:FOLLOWER]], @state.delta(:current_role)
		assert_equal [["alice"], ["bob"], ["carol"]], @state.delta(:current_members)
	end

	def test_updates
		@state.sync_callback(:update_term, [[1]], :current_term)
		@state.sync_callback(:update_max_term_voted, [[1]], :max_term_voted)
		@state.sync_callback(:update_role, [[:LEADER]], :current_role)
		assert_equal [["alice"], ["bob"], ["carol"]], @state.delta(:current_members)

		@state.tick
		
		assert_equal [[1]], @state.delta(:current_term)
		assert_equal [[1]], @state.delta(:max_term_voted)
		assert_equal [[:LEADER]], @state.delta(:current_role)
		assert_equal [["alice"], ["bob"], ["carol"]], @state.delta(:current_members)
	end
end
