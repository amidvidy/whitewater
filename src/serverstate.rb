require 'rubygems'
require 'bud'

module ServerStateProtocol
	state	do
		interface input, :update_term, [:term]
		interface input, :update_max_term_voted, [:max_term]
		interface input, :update_role, [:role]

		interface output, :current_term, [:term]
		interface output, :max_term_voted, [:max_term]
		interface output, :current_role, [:role]
		interface output, :current_members, [:host]
	end
end

module ServerStateImpl
	include ServerStateProtocol

	state do
		lmax :term
		lmax :term_voted
		table :members, [:host]
		table :role, [] => [:role]
	end

	bloom :update do
		term <= update_term { |t| Bud::MaxLattice.new(t[0]) }
		term_voted <= update_max_term_voted { |t| Bud::MaxLattice.new(t[0]) }
		role <+- update_role { |r| r if [[:LEADER], [:FOLLOWER], [:CANDIDATE]].include? r }
	end

	bloom :output do
		current_term <= [[term.reveal]]
		max_term_voted <= [[term_voted.reveal]]
		current_role <= role
		current_members <= members
	end
end
