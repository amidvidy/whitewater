require 'rubygems'
require 'bud'

module MembershipProtocol
  state do
#    interface input, :my_id, [:ident]
    interface input, :add_member, [:ident] => [:host]
    interface input, :remove_member, [:ident]
    interface output, :member, [:ident] => [:host]

    interface output, :added_member, [:ident] => [:host]
#    interface output, :removed_member, [:ident] => [:host]
  end
end

module StaticMembership
  include MembershipProtocol

  state do
    table :private_members, [:ident] => [:host]
  end

  bloom do
    # add member to private_members
    private_members <= add_member { |m| [m.ident, m.host] }
    # remove member, unnecessary for StaticMembership
    private_members <- (remove_member * private_members).pairs(:ident => :ident)
    member <= private_members
  end

  bloom :report_status do
    added_member <= (add_member * private_members).pairs(:ident => :ident)
  end
end
