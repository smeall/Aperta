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

describe Admin::JournalsController, redis: true do
  let(:journal) do
    FactoryGirl.create(
      :journal,
      :with_creator_role,
      :with_staff_admin_role
    )
  end
  let(:user) { FactoryGirl.build_stubbed :user, :site_admin }

  describe '#create' do
    subject(:do_request) do
      post :create,
           format: 'json',
           admin_journal: { name: 'new journal name',
                            description: 'new journal desc',
                            doi_journal_prefix: 'journal.SHORTJPREFIX1',
                            doi_publisher_prefix: 'SHORTJPREFIX1',
                            last_doi_issued: '100001',
                            logo_url: logo_url
                          }
    end

    let(:logo_url) { nil } # by default, do not upload logo

    it_behaves_like "an unauthenticated json request"

    context 'when the user has access' do
      before do
        stub_sign_in user
        expect(user).to receive(:site_admin?).and_return(true).at_least(:once)
        CardTaskType.seed_defaults
      end

      it 'creates a journal' do
        expect do
          do_request
        end.to change { Journal.count }.by 1
        journal = Journal.last
        expect(journal.name).to eq 'new journal name'
        expect(journal.description).to eq 'new journal desc'
        expect(response.status).to eq 201
      end

      describe 'uploading journal logo' do
        context 'when url is provided' do
          let(:logo_url) { 'http://s3.com/pending/logo.png' }

          it 'calls the journal logo service class' do
            expect(DownloadJournalLogoWorker).to receive(:perform_async).with(kind_of(Integer), logo_url)
            do_request
          end
        end

        context 'when url is not provided' do
          it 'does not call the journal logo service class' do
            expect(DownloadJournalLogoWorker).to_not receive(:perform_async)
            do_request
          end
        end

        context 'when url is not a new logo stored in a temporary s3 bucket' do
          let(:logo_url) { 'http://s3.com/logo.png' }

          it 'does not call the journal logo service class' do
            expect(DownloadJournalLogoWorker).to_not receive(:perform_async)
            do_request
          end
        end
      end
    end

    context "when the user does not have access" do
      before do
        stub_sign_in user
        expect(user).to receive(:site_admin?).and_return(false)
      end

      it "renders status 403" do
        do_request
        expect(response.status).to eq 403
      end
    end

    context "when the user is unauthorized" do
      it "renders status 401" do
        do_request
        expect(response.status).to eq 401
      end
    end
  end

  describe '#update' do
    subject(:do_request) do
      patch :update,
            format: 'json',
            id: journal.id,
            admin_journal: {name: 'new journal name'}
    end

    it_behaves_like "an unauthenticated json request"

    context "when the user has access" do
      before do
        stub_sign_in user
        allow(user).to receive(:can?)
          .with(:administer, journal)
          .and_return true
      end

      it "renders status 2xx and the journal is updated successfully" do
        expect do
          do_request
        end.to change { Journal.pluck(:name) }.to contain_exactly 'new journal name'
        expect(response.status).to eq 204
      end
    end

    context "when the user does not have access" do
      before do
        stub_sign_in user
        allow(user).to receive(:can?)
          .with(:administer, journal)
          .and_return false
      end

      it "renders status 403" do
        do_request
        expect(response.status).to eq 403
      end
    end
  end

  describe '#show' do
    subject(:do_request) { get :show, format: 'json', id: '', admin_journal: { foo: 'bar' } }
    it 'should not call JournalFactory#create' do
      stub_sign_in user
      expect(JournalFactory).to_not receive(:create)
      do_request
    end
  end
end
