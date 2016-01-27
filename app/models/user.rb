class User < ActiveRecord::Base
  include UserHelper
  include UserDevise

  include PgSearch
  pg_search_scope :fuzzy_search,
    against: [:first_name, :last_name, :email, :username],
    ignoring: :accents,
    using: { tsearch: { prefix: true }, trigram: { threshold: 0.3 } }

  has_many :affiliations, inverse_of: :user
  has_many :submitted_papers, inverse_of: :creator, class_name: 'Paper'
  has_many :paper_roles
  has_many :papers, -> { uniq }, through: :paper_roles
  has_many :user_roles, inverse_of: :user
  has_many :old_roles, through: :user_roles
  has_many :journals, ->{ uniq }, through: :old_roles
  has_many :user_flows, inverse_of: :user, dependent: :destroy
  has_many :flows, through: :user_flows
  has_many :comments, inverse_of: :commenter, foreign_key: 'commenter_id'
  has_many :participations, dependent: :destroy
  has_many :tasks, through: :participations
  has_many :comment_looks, inverse_of: :user
  has_many :credentials, inverse_of: :user, dependent: :destroy
  has_many :assigned_papers, ->{ uniq }, through: :paper_roles, class_name: 'Paper', source: :paper
  has_many :invitations, foreign_key: :invitee_id, inverse_of: :invitee
  has_many :discussion_replies, foreign_key: :replier_id, inverse_of: :replier, dependent: :destroy
  has_many :discussion_participants, inverse_of: :user, dependent: :destroy
  has_many :discussion_topics, through: :discussion_participants
  has_many :notifications, inverse_of: :paper

  attr_accessor :login

  validates :username, presence: true, uniqueness: { case_sensitive: false }, length: { maximum: 255 }
  validates_format_of :username, with: /\A[A-Za-z\d_]+\z/, multiline: true
  validates :email, format: Devise.email_regexp
  validates :first_name, length: { maximum: 255 }
  validates :last_name, length: { maximum: 255 }

  mount_uploader :avatar, AvatarUploader

  if Rails.configuration.password_auth_enabled
    devise :trackable, :omniauthable, :database_authenticatable, :registerable, :recoverable, :rememberable, :validatable,
      authentication_keys: [:login], omniauth_providers: Rails.configuration.omniauth_providers
  else
    devise :trackable, :omniauthable, omniauth_providers: Rails.configuration.omniauth_providers
  end

  def password_required?
    Rails.configuration.password_auth_enabled && super
  end

  def possible_flows
    Flow.where("old_role_id IN (?) OR old_role_id IS NULL", old_role_ids)
  end

  def self.site_admins
    where(site_admin: true)
  end

  def full_name
    "#{first_name} #{last_name}"
  end

  def can_view_flow_manager?
    old_roles.can_view_flow_manager.present?
  end

  def auto_generate_password(length=50)
    self.password = SecureRandom.urlsafe_base64(length-1) if password_required?
  end

  def journal_admin?(journal)
    administered_journals.include? journal
  end

  def administered_journals
    if site_admin?
      Journal.all
    else
      filter_authorized(:administer, Journal.all).objects
    end
  end

  def accessible_journals
    site_admin? ? Journal.all : journals
  end

  def invitations_from_latest_revision
    # Includes, here, to enable selecting from the latest revision w/o
    # further db queries.
    invitations.includes([{ decision: [:paper] }, :paper]).select do |invitation|
      invitation.decision && invitation.decision.latest?
    end
  end

  def self.search_users(query: nil, assigned_users_in_journal_id: nil)
    if query
      sanitized_query = connection.quote_string(query.to_s.downcase) + '%'
      User.fuzzy_search sanitized_query
    elsif assigned_users_in_journal_id
      User.joins(user_roles: :old_role).where('old_roles.journal_id = ?', assigned_users_in_journal_id).uniq
    end
  end
end
