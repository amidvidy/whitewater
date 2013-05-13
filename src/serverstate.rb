require 'rubygems'
require 'bud'

module ServerStateProto
  state do
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
  include ServerStateProto

  ROLES = [[:LEADER], [:FOLLOWER], [:CANDIDATE]]

  state do
    lmax :term
    lmax :term_voted
    table :members, [:host]
    table :role, [] => [:role]
  end

  bloom :update do
    term <= update_term { |t| Bud::MaxLattice.new t.term }
    term_voted <= update_max_term_voted { |t| Bud::MaxLattice.new t.max_term }
    role <+- update_role { |r| r if ServerStateImpl::ROLES.include? r }
  end

  bloom :output do
    current_term <= [[term.reveal]]
    max_term_voted <= [[term_voted.reveal]]
    current_role <= role
    current_members <= members
  end
end
