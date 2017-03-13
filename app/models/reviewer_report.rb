class ReviewerReport < ActiveRecord::Base
  include Answerable
  include NestedQuestionable

  default_scope { order('decision_id DESC') }

  belongs_to :task, foreign_key: :task_id
  belongs_to :user
  belongs_to :decision

  validates :task,
    uniqueness: { scope: [:task_id, :user_id, :decision_id],
                  message: 'Only one report allowed per reviewer per decision' }

  def invitation
    decision.invitations.find_by(invitee_id: user.id)
  end

  # status will look at the reviewer, invitations and the submitted state of
  # this task to get an overall status for the review
  # rubocop:disable Metrics/CyclomaticComplexity
  def computed_status
    if invitation
      if invitation.state == "accepted"
        if task.submitted?
          "completed"
        else
          "pending"
        end
      else
        "invitation_#{invitation.state}"
      end
    else
      "not_invited"
    end
  end

  def computed_status_datetime
    case computed_status
    when "completed"
      task.completed_at
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
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity

  def revision
    # if a decision has a revision, use it, otherwise, use paper's
    major_version = decision.major_version || task.paper.major_version || 0
    minor_version = decision.minor_version || task.paper.minor_version || 0
    "v#{major_version}.#{minor_version}"
  end
end
