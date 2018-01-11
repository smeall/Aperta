# coding: utf-8
class PaperReviewerTask < ::Task
  DEFAULT_TITLE = 'Invite Reviewers'.freeze
  DEFAULT_ROLE_HINT = 'editor'.freeze

  include Invitable

  def invitation_invited(invitation)
    ReviewerMailer.delay.notify_invited invitation_id: invitation.id
  end

  def invitation_accepted(invitation)
    ReviewerReportTaskCreator.new(
      originating_task: self,
      assignee_id: invitation.invitee_id
    ).process
    ReviewerMailer.delay.reviewer_accepted(invitation_id: invitation.id)
  end

  def invitation_declined(invitation)
    ReviewerMailer.delay.reviewer_declined(invitation_id: invitation.id)
  end

  def invitation_rescinded(invitation)
    if invitation.invitee.present?
      invitation.invitee.resign_from!(assigned_to: invitation.task.journal,
                                      role: invitation.invitee_role)
    end
  end

  def active_invitation_queue
    paper.draft_decision.invitation_queue ||
      InvitationQueue.create(task: self, decision: paper.draft_decision)
  end

  def array_attributes
    super + [:reviewer_ids]
  end

  def self.permitted_attributes
    super + [{ reviewer_ids: [] }]
  end

  def update_responder
    UpdateResponders::PaperReviewerTask
  end

  def invitee_role
    Role::REVIEWER_ROLE
  end

  def invitation_template
    OldLetterTemplate.new(
      salutation: "Dear [REVIEWER NAME],",
      body: invitation_body_template
    )
  end

  def accept_allowed?(invitation)
    # Prevents accepting invitation without an invitee
    invitation.invitee.present?
  end
end
