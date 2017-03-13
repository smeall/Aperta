# This class represents the reviewer reports per decision round
class ReviewerReport < ActiveRecord::Base
  include Answerable
  include NestedQuestionable
  include AASM

  default_scope { order('decision_id DESC') }

  belongs_to :task, foreign_key: :task_id
  belongs_to :user
  belongs_to :decision

  validates :task,
    uniqueness: { scope: [:task_id, :user_id, :decision_id],
                  message: 'Only one report allowed per reviewer per decision' }

  def self.for_invitation(invitation)
    reports = ReviewerReport.where(user: invitation.invitee,
                                   decision: invitation.decision)
    if reports.count > 1
      raise "More than one reviewer report for invitation (#{invitation.id})"
    end
    reports.first
  end

  aasm column: :state do
    state :invitation_pending, initial: true
    state :review_pending
    state :submitted

    event(:accept_invitation,
          guards: [:invitation_accepted?],
          after: [:update_invitation_status]) do
      transitions from: :invitation_pending, to: :review_pending
    end

    event(:rescind_invitation,
          after: [:update_invitation_status]) do
      transitions from: :review_pending, to: :invitation_pending
    end

    event(:submit,
          guards: [:invitation_accepted?], after: [:set_submitted_status]) do
      transitions from: :review_pending, to: :submitted
    end
  end

  def invitation
    @invitation ||= decision.invitations.find_by(invitee_id: user.id)
  end

  def invitation_accepted?
    invitation.accepted?
  end

  def revision
    # if a decision has a revision, use it, otherwise, use paper's
    major_version = decision.major_version || task.paper.major_version || 0
    minor_version = decision.minor_version || task.paper.minor_version || 0
    "v#{major_version}.#{minor_version}"
  end

  def update_invitation_status
    update!(status: compute_invitation_state,
            status_datetime: compute_invitation_datetime) if !submitted?
  end

  private

  def set_submitted_status
    update!(status: 'completed', status_datetime: Time.current.utc)
  end

  # status will look at the reviewer, invitations and the submitted state of
  # this task to get an overall status for the review
  def computed_status
    case aasm.current_state
    when STATE_INVITATION_PENDING
      compute_invitation_state
    when STATE_REVIEW_PENDING
      "pending"
    when STATE_SUBMITTED
      "completed"
    end
  end

  def compute_invitation_state
    if invitation
      "invitation_#{invitation.state}"
    else
      "not_invited"
    end
  end

  def compute_invitation_datetime
    case computed_status
    when "pending"
      invitation.accepted_at
    when "invitation_invited"
      invitation.invited_at
    when "invitation_accepted"
      invitation.accepted_at
    when "invitation_declined"
      invitation.declined_at
    when "invitation_rescinded"
      invitation.rescinded_at
    else
      Time.current.utc
    end
  end
end
