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

describe TaskEligibleUsersController do
  let(:user) { FactoryGirl.create :user }
  let(:paper) { FactoryGirl.create :paper, :submitted_lite, journal: journal }
  let(:task) { FactoryGirl.create :ad_hoc_task, paper: paper }

  describe "#academic_editors" do
    let(:journal) do
      FactoryGirl.create(:journal, :with_academic_editor_role)
    end
    subject(:do_request) do
      get(
        :academic_editors,
        format: 'json',
        task_id: task.to_param,
        query: 'Kangaroo'
      )
    end

    it_behaves_like 'an unauthenticated json request'

    context 'when the user has access and there are eligible academic editors' do
      let(:eligible_users) do
        [FactoryGirl.build_stubbed(:user, email: 'foo@example.com')]
      end
      before do
        stub_sign_in(user)
        allow(user).to receive(:can?)
          .with(:edit, task)
          .and_return true
        allow(user).to receive(:can?)
          .with(:search_academic_editors, task.paper)
          .and_return true

        allow(EligibleUserService).to receive(:eligible_users_for)
          .with(paper: paper, role: journal.academic_editor_role, matching: 'Kangaroo')
          .and_return eligible_users
        do_request
      end

      it { is_expected.to responds_with(200) }

      it 'returns users who are eligible to be assigned to the provided role' do
        expect(res_body['users'].count).to eq(1)
        expect(res_body['users'][0]['email']).to eq('foo@example.com')
      end
    end

    context 'when the user does not have access' do
      context 'the user can edit the task but does not have permission to search' do
        before do
          stub_sign_in(user)
          allow(user).to receive(:can?)
            .with(:edit, task)
            .and_return true
          allow(user).to receive(:can?)
            .with(:search_academic_editors, task.paper)
            .and_return false

          do_request
        end
        it { is_expected.to responds_with(403) }
      end
      context 'the user has permission to search but cannot edit the task' do
        before do
          stub_sign_in(user)
          allow(user).to receive(:can?)
            .with(:edit, task)
            .and_return false
          allow(user).to receive(:can?)
            .with(:search_academic_editors, task.paper)
            .and_return true

          do_request
        end
        it { is_expected.to responds_with(403) }
      end

    end
  end

  describe "#admins" do
    let(:journal) { FactoryGirl.create(:journal, :with_staff_admin_role) }
    subject(:do_request) do
      get(
        :admins,
        format: 'json',
        task_id: task.to_param,
        query: 'Kangaroo'
      )
    end

    it_behaves_like 'an unauthenticated json request'

    context 'when the user has access and there are eligible staff admins' do
      let(:eligible_users) do
        [FactoryGirl.build_stubbed(:user, email: 'foo@example.com')]
      end
      before do
        stub_sign_in(user)
        allow(user).to receive(:can?)
          .with(:edit, task)
          .and_return true
        allow(user).to receive(:can?)
          .with(:search_admins, task.paper)
          .and_return true

        allow(EligibleUserService).to receive(:eligible_users_for)
          .with(paper: paper, role: journal.staff_admin_role, matching: 'Kangaroo')
          .and_return eligible_users
        do_request
      end

      it { is_expected.to responds_with(200) }

      it 'returns users who are eligible to be assigned to the provided role' do
        expect(res_body['users'].count).to eq(1)
        expect(res_body['users'][0]['email']).to eq('foo@example.com')
      end
    end

    context 'when the user does not have access' do
      context 'the user can edit the task but does not have permission to search' do
        before do
          stub_sign_in(user)
          allow(user).to receive(:can?)
            .with(:edit, task)
            .and_return true
          allow(user).to receive(:can?)
            .with(:search_admins, task.paper)
            .and_return false

          do_request
        end
        it { is_expected.to responds_with(403) }
      end
      context 'the user has permission to search but cannot edit the task' do
        before do
          stub_sign_in(user)
          allow(user).to receive(:can?)
            .with(:edit, task)
            .and_return false
          allow(user).to receive(:can?)
            .with(:search_admins, task.paper)
            .and_return true

          do_request
        end
        it { is_expected.to responds_with(403) }
      end
    end
  end
  describe "#reviewers" do
    let(:journal) { FactoryGirl.create(:journal) }
    subject(:do_request) do
      get(
        :reviewers,
        format: 'json',
        task_id: task.to_param,
        query: 'Kangaroo'
      )
    end

    it_behaves_like 'an unauthenticated json request'

    context 'when the user has access' do
      let(:eligible_users) do
        [FactoryGirl.build_stubbed(:user, email: 'foo@example.com')]
      end
      before do
        stub_sign_in(user)
        allow(user).to receive(:can?)
          .with(:edit, task)
          .and_return true
        allow(user).to receive(:can?)
          .with(:search_reviewers, task.paper)
          .and_return true
        allow(User).to receive(:fuzzy_search)
          .with('Kangaroo')
          .and_return eligible_users

        do_request
      end

      it { is_expected.to responds_with(200) }

      it 'returns any user who matches the query' do
        expect(res_body['users'].count).to eq(1)
        expect(res_body['users'][0]['email']).to eq('foo@example.com')
      end
    end

    context 'when the user does not have access' do
      context 'the user can edit the task but does not have permission to search' do
        before do
          stub_sign_in(user)
          allow(user).to receive(:can?)
            .with(:edit, task)
            .and_return true
          allow(user).to receive(:can?)
            .with(:search_reviewers, task.paper)
            .and_return false

          do_request
        end
        it { is_expected.to responds_with(403) }
      end
      context 'the user has permission to search but cannot edit the task' do
        before do
          stub_sign_in(user)
          allow(user).to receive(:can?)
            .with(:edit, task)
            .and_return false
          allow(user).to receive(:can?)
            .with(:search_reviewers, task.paper)
            .and_return true

          do_request
        end
        it { is_expected.to responds_with(403) }
      end
    end
  end
end
