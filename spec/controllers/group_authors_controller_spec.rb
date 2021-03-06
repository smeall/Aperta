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

require 'rails_helper'

describe GroupAuthorsController do
  let(:user) { FactoryGirl.create(:user) }
  let(:task) { FactoryGirl.create(:authors_task, paper: paper) }
  let(:paper) { FactoryGirl.create(:paper) }
  let(:post_request) do
    post :create,
         format: :json,
         group_author: {
           name: "Freddy Group",
           contact_first_name: "enrico",
           contact_last_name: "fermi",
           paper_id: paper.id,
           task_id: task.id,
           position: 1
         }
  end
  let!(:group_author) { FactoryGirl.create(:group_author, paper: paper) }
  let(:delete_request) { delete :destroy, format: :json, id: group_author.id }
  let(:put_request) do
    put :update,
        format: :json,
        id: group_author.id,
        group_author: {
          contact_last_name: "Blabby",
          task_id: task.id
        }
  end

  before do
    CardLoader.load("GroupAuthor")
    allow(request.env['warden']).to receive(:authenticate!).and_return(user)
    allow(controller).to receive(:current_user).and_return(user)
  end

  describe "when the current user can edit_authors on the paper" do
    before do
      allow(user).to receive(:can?).with(:view, paper).and_return(true)
      allow(user).to receive(:can?).with(:manage_paper_authors, group_author.paper).and_return(true)
      allow(user).to receive(:can?).with(:edit_authors, paper).and_return(true)
    end

    it 'a POST request creates a new author' do
      expect { post_request }.to change { GroupAuthor.count }.by(1)
    end

    it 'a PUT request updates the author' do
      put_request
      expect(group_author.reload.contact_last_name).to eq "Blabby"
    end

    context 'the group author belongs paper that also has an author with an orcid account and orcid connect is enabled' do
      before do
        allow_any_instance_of(TahiEnv).to receive(:orcid_connect_enabled?).and_return(true)
        user = FactoryGirl.create(:user)
        FactoryGirl.create(:author, user: user, paper: paper)
        FactoryGirl.create(:orcid_account, user: user)
      end
      it 'serializes the orcid account for the author' do
        put_request
        expect(res_body).to have_key('orcid_accounts')
      end
    end

    it 'a DELETE request deletes the author' do
      expect { delete_request }.to change { GroupAuthor.count }.by(-1)
    end
  end

  describe "when the current user can NOT edit_authors on the paper" do
    before do
      allow(user).to receive(:can?).with(:edit_authors, paper).and_return(false)
    end

    it 'a POST request does not create a new author' do
      expect { post_request }.not_to change { GroupAuthor.count }
    end

    it 'a PUT request does not update an author' do
      put_request
      expect(group_author.reload.contact_last_name).not_to eq "Blabby"
    end

    it 'a DELETE request does not delete an author' do
      expect { delete_request }.not_to change { GroupAuthor.count }
    end

    it 'a POST request responds with a 403' do
      post_request
      expect(response).to have_http_status(:forbidden)
    end

    it 'a PUT request responds with a 403' do
      put_request
      expect(response).to have_http_status(:forbidden)
    end

    it 'a DELETE request responds with a 403' do
      delete_request
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe 'coauthor update' do
    let!(:time) { Time.now.utc }

    let!(:staff_admin) { FactoryGirl.create(:user, :site_admin) }

    let(:group_author) do
      Timecop.freeze(1.day.ago) do
        FactoryGirl.create(:group_author, co_author_state: "unconfirmed",
                                          co_author_state_modified_at: time,
                                          co_author_state_modified_by_id: staff_admin.id,
                                          paper: paper)
      end
    end

    let(:put_request) do
      put :update, format: :json, id: group_author.id, group_author: { contact_last_name: "Blabby",
                                                                       author_task_id: task.id,
                                                                       co_author_state: "confirmed",
                                                                       co_author_state_modified_by: staff_admin }
    end

    context 'paper-manager user' do
      it 'a PUT request from an paper-manager allows updating coauthor status' do
        allow(user).to receive(:can?).with(:view, paper).and_return(true)
        allow(user).to receive(:can?).with(:edit_authors, group_author.paper).and_return(true)
        allow(user).to receive(:can?).with(:manage_paper_authors, group_author.paper).and_return(true)

        old_time = group_author.co_author_state_modified_at

        put_request
        group_author.reload
        expect(group_author.contact_last_name).to eq "Blabby"
        expect(group_author.co_author_state).to eq "confirmed"
        expect(group_author.co_author_state_modified_at).to be > old_time
        expect(group_author.co_author_state_modified_by_id).to eq user.id
      end

      context 'non-paper-manager user with edit access'

      it 'a PUT request from an non-paper-manager skips updating coauthor status' do
        allow(user).to receive(:can?).with(:view, paper).and_return(true)
        allow(user).to receive(:can?).with(:edit_authors, group_author.paper).and_return(true)
        allow(user).to receive(:can?).with(:manage_paper_authors, group_author.paper).and_return(false)

        old_time = group_author.co_author_state_modified_at

        put_request
        group_author.reload
        expect(group_author.contact_last_name).to eq "Blabby"
        expect(group_author.co_author_state).to eq "unconfirmed"
        # TODO: Fix time issue on CI
        # expect(group_author.co_author_state_modified_at).to eq old_time
        expect(group_author.co_author_state_modified_by_id).to eq staff_admin.id
      end
    end
  end
end
