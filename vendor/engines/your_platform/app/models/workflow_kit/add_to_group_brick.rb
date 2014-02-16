# -*- coding: utf-8 -*-
module WorkflowKit
  class AddToGroupBrick < Brick
    def name 
      "Add User to Group"
    end
    def description
      "Add the given user to the given group as a new member. " +
        "The new group has to be passed as a parameter to the workflow step."
    end
    def execute( params )
      raise 'no user_id given' unless params[ :user_id ] 
      raise 'no group_id given' unless params[ :group_id ]

      user = User.find( params[ :user_id ] )  
      group = Group.find( params[ :group_id ] )

      membership = UserGroupMembership.find_by( user: user, group: group )
      membership ||= UserGroupMembership.create( user: user, group: group )
      membership.try( :make_valid )

    end
  end
end
