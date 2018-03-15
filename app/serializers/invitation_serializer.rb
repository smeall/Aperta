class InvitationSerializer < AuthzSerializer
  attributes :id,
             :body,
             :created_at,
             :decline_reason,
             :email,
             :invitee_role,
             :reviewer_suggestions,
             :state,
             :updated_at,
             :invited_at,
             :declined_at,
             :accepted_at,
             :rescinded_at,
             :position,
             :decision_id,
             :valid_new_positions_for_invitation,
             :due_in

  has_one :invitee, serializer: FilteredUserSerializer, embed: :id, root: :users, include: true
  has_one :actor, serializer: FilteredUserSerializer, embed: :id, root: :users, include: true
  has_one :task, embed: :id, polymorphic: true
  has_many :attachments, embed: :id, polymorphic: true, include: true
  has_one :primary, embed: :id
  has_many :alternates, embed: :id
  has_one :reviewer_report, embed: :id, include: false

  def valid_new_positions_for_invitation
    object.invitation_queue.valid_new_positions_for_invitation(object)
  end

  def reviewer_report
    ReviewerReport.for_invitation(object)
  end
end
