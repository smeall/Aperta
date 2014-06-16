class PapersPolicy < ApplicationPolicy
  allow_params :paper

  def show?
    current_user.admin? || author? || paper_admin? || paper_editor? || paper_reviewer? || can_view_manuscript_manager?
  end

  def edit?
    current_user.admin? || author? || paper_admin? || paper_editor? || paper_reviewer?
  end

  def create?
    current_user.present?
  end

  def update?
    current_user.admin? || author? || paper_admin? || paper_editor? || paper_reviewer?
  end

  def upload?
    current_user.admin? || author? || paper_admin? || paper_editor? || paper_reviewer? || can_view_manuscript_manager?
  end

  def download?
    current_user.admin? || author? || paper_admin? || paper_editor? || paper_reviewer?
  end

  private

  %w(editor reviewer admin).each do |role|
    define_method "paper_#{role}?" do
      paper.role_for(role: role, user: current_user).present?
    end
  end

  def can_view_manuscript_manager?
    current_user.roles.where(journal_id: paper.journal).where(can_view_all_manuscript_managers: true).present?
  end

  def author?
    current_user.submitted_papers.where(id: paper.id).present?
  end
end
