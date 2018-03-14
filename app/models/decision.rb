class Decision < ActiveRecord::Base
  include ViewableModel
  include EventStream::Notifiable
  include Versioned
  include CustomCastTypes

  attribute :letter, HtmlString.new
  attribute :author_response, HtmlString.new

  REVISION_VERDICTS = ['major_revision', 'minor_revision']
  TERMINAL_VERDICTS = ['accept', 'reject']
  PUBLISHING_STATE_BY_VERDICT = {
    "minor_revision" => "in_revision",
    "major_revision" => "in_revision",
    "accept" => "accepted",
    "reject" => "rejected",
    "invite_full_submission" => "invited_for_full_submission"
  }

  VERDICTS = PUBLISHING_STATE_BY_VERDICT.keys

  scope :revisions, -> { where(verdict: REVISION_VERDICTS) }

  belongs_to :paper
  has_many :invitations
  has_one :invitation_queue
  # TODO: APERTA-9226 remove or change. we can probably eliminate
  # this relationship entirely at this point since answers belong to reports
  # more meaningfully.
  has_many :reviewer_reports
  has_many :attachments, as: :owner,
                         class_name: 'DecisionAttachment',
                         dependent: :destroy

  validates :verdict, inclusion: { in: VERDICTS, message: 'must be a valid choice' }, if: -> { verdict }

  validate do
    if author_response_changed? && !latest_registered? && persisted?
      errors.add(
        :author_response,
        'Author response can only change on the latest registered decision')
    end
  end

  validate do
    if letter_changed? && completed? && persisted?
      errors.add(:letter, 'Letter can only change on draft decisions')
    end
    if verdict_changed? && completed? && persisted?
      errors.add(:verdict, 'Verdict can only change on draft decisions')
    end
  end

  def register!(originating_task)
    Decision.transaction do
      originating_task.try(:before_register, self)
      paper.public_send "#{verdict}!"
      update! major_version: paper.major_version,
              minor_version: paper.minor_version,
              registered_at: DateTime.now.utc
      originating_task.try(:after_register, self)
      reviewer_reports.each(&:cancel_reminders)
    end
  end

  # Decisions can be appealed, and if editorial staff agrees the wrong
  # decision was made, they rescind that choice.
  def rescind!
    Decision.transaction do
      if initial
        paper.rescind_initial_decision!
      else
        paper.rescind_decision!
      end
      update! rescinded: true
    end
  end

  def latest_registered?
    self == paper.decisions.version_asc.completed.last
  end

  def revision?
    REVISION_VERDICTS.include? verdict
  end

  def terminal?
    TERMINAL_VERDICTS.include? verdict
  end

  def rescindable?
    latest_registered? &&
      paper_in_expected_state_given_verdict? &&
      !rescinded
  end

  def latest_invitation(invitee_id:)
    invitations.where(invitee_id: invitee_id).order(:created_at).last
  end

  def user_can_view?(user)
    user.can?(:view_decisions, paper)
  end

  private

  def paper_in_expected_state_given_verdict?
    paper.publishing_state == PUBLISHING_STATE_BY_VERDICT[verdict]
  end
end
