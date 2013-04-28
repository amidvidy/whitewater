require 'rubygems'
require 'bud'

# Used to hold elections.
# Adam: Pretty sure this is a good design
module VoteCounterProtocol
  state do
    interface input, :start_vote, [:prop] => [:threshold]
    interface input, :submit_ballot, [:voter, :prop] => []
    interface output, :outcome, [:prop] => []
  end
end

module VoteCounterImpl
  include VoteCounterProtocol

  state do
    table :proposition, start_vote.schema
    lmap :ballots
  end

  bloom :start_vote do
    proposition <= start_vote
  end

  bloom :submit_ballot do
    ballots <= submit_ballot {|sb| {sb.prop => Bud::SetLattice.new([sb.voter])}}
  end

  bloom :outcome do
    outcome <= proposition do |p|
      ballots.at(p.prop, Bud::SetLattice).size.gt_eq(p.threshold).when_true do
        [p.prop]
      end
    end
  end
end
