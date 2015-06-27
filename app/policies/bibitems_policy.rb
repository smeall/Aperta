class BibitemsPolicy < ApplicationPolicy
  primary_resource :bibitem

  def connected_users
    papers_policy.connected_users
  end

  def create?
    papers_policy.show?
  end

  def update?
    papers_policy.show?
  end

  def destroy?
    papers_policy.show?
  end

  def show?
    papers_policy.show?
  end

  private

  def papers_policy
    @papers_policy ||= PapersPolicy.new(current_user: current_user, resource: bibitem.paper)
  end
end