# Copyright (c) 2018 Public Library of Science

# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

class AuthorsController < ApplicationController
  before_action :authenticate_user!
  respond_to :json

  def show
    requires_user_can_view author
    render json: author
  end

  def create
    paper = Paper.find_by_id_or_short_doi(author_params[:paper_id])
    requires_user_can :edit_authors, paper
    author = Author.new(author_params)
    author.save!
    author.author_list_item.move_to_bottom

    # render all authors, since position is controlled by acts_as_list
    render json: author_list_payload(author)
  end

  def update
    requires_user_can :edit_authors, author.paper
    author.update!(author_params)

    if current_user.can? :manage_paper_authors, author.paper
      author.update_coauthor_state(author_coauthor_state, current_user.id)
    end

    # render all authors, since position is controlled by acts_as_list
    render json: author_list_payload(author)
  end

  def destroy
    requires_user_can :edit_authors, author.paper
    author.destroy!

    # render all authors, since position is controlled by acts_as_list
    render json: author_list_payload(author)
  end

  private

  def author
    @author ||= Author.includes(:author_list_item).find(params[:id])
  end

  def author_list_payload(author)
    # The PaperAuthorSerializer eventually invokes the OrcidAccountSerializer if
    # circumstances are right (TahiEnv.orcid_connect_enabled and the author
    # belongs to a user with an orcid account). Since we're manually creating
    # the PaperAuthorSerializer we need to set the scope and the scope name
    # manually as well. This process is normally taken care of for us by active
    # model serializers.
    serializer = PaperAuthorSerializer.new(
      author.paper,
      root: 'paper',
      scope: current_user,
      scope_name: :current_user
    )
    hash = serializer.as_json
    hash.delete("paper")
    hash
  end

  def author_coauthor_state
    params.require(:author).permit(:co_author_state)[:co_author_state]
  end

  def author_params
    params.require(:author).permit(
      :author_initial,
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
      :department,
      :current_address_street,
      :current_address_street2,
      :current_address_city,
      :current_address_state,
      :current_address_country,
      :current_address_postal
    )
  end
end
