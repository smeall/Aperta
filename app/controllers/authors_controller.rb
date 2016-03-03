class AuthorsController < ApplicationController
  before_action :authenticate_user!
  respond_to :json

  def show
    requires_user_can :view, author.paper
    render json: author
  end

  def create
    requires_user_can :edit_authors, author.paper
    author.save!

    # render all authors, since position is controlled by acts_as_list
    render json: author.paper.authors, each_serializer: AuthorSerializer
  end

  def update
    requires_user_can :edit_authors, author.paper
    author.update!(author_params)

    # render all authors, since position is controlled by acts_as_list
    render json: author.paper.authors, each_serializer: AuthorSerializer
  end

  def destroy
    requires_user_can :edit_authors, author.paper
    author.destroy!

    # render all authors, since position is controlled by acts_as_list
    render json: author.paper.authors, each_serializer: AuthorSerializer
  end

  private

  def author
    @author ||= begin
      if params[:id].present?
        Author.find(params[:id])
      else
        Author.new(author_params)
      end
    end
  end

  def author_params
    params.require(:author).permit(
      :authors_task_id,
      :first_name,
      :last_name,
      :position,
      :paper_id,
      :position,
      :first_name,
      :middle_initial,
      :last_name,
      :email,
      :affiliation,
      :secondary_affiliation,
      :title,
      :department
    )
  end
end
