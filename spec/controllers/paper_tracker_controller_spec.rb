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

describe PaperTrackerController do
  let(:per_page) { Kaminari.config.default_per_page }
  let(:journal) do
    FactoryGirl.create(
      :journal, :with_creator_role, :with_admin_roles,
      doi_publisher_prefix: "10.9999",
      doi_journal_prefix: "journal."
    )
  end

  before { sign_in user }

  describe 'let(per_page)' do
    let(:user) { FactoryGirl.create :user }

    it 'is available and useful' do
      expect(per_page).to be_truthy
      expect(per_page.instance_of?(Fixnum)).to eq(true)
    end
  end

  describe 'without the permission' do
    let(:user) { FactoryGirl.create :user }

    before do
      allow_any_instance_of(User).to receive(:filter_authorized)
        .with(:view_paper_tracker, Journal, participations_only: false)
        .and_return double('ResultSet', objects: [])
    end

    it 'returns a 403' do
      get :index, format: :json
      expect(response.status).to eq(403)
    end
  end

  describe '#order_dir' do
    let(:user) { FactoryGirl.create :user }
    before { expect(controller).to receive(:params).and_return(orderDir: value) }
    ['foo', 'asc', 'desc'].each do |val|
      context "with #{val} param" do
        let(:value) { val }
        it "it returns the correct value" do
          expect(controller.send(:order_dir)).to eql(val == 'desc' ? 'desc' : 'asc')
        end
      end
    end
  end

  describe '#column' do
    let(:user) { FactoryGirl.create :user }

    Paper.column_names.dup.push('bogus').each do |val|
      context "with #{val} param" do
        it "returns the correct value" do
          allow(controller).to receive(:params).and_return(orderBy: val)
          expect(controller.send(:column)).to eql(val == 'bogus' ? 'submitted_at' : val)
        end
      end
    end
  end

  describe 'on GET #index' do
    let(:user) { FactoryGirl.create :user, :site_admin }

    it 'list the paper in journal that user belongs to' do
      paper = make_matchable_paper
      get :index, format: :json
      json = JSON.parse(response.body)
      expect(json['papers'].size).to eq 1
      expect(json['papers'][0]['title']).to eq paper.title
    end

    it 'does not list the paper if is not submitted' do
      paper = FactoryGirl.create(:paper, journal: journal)
      assign_journal_role(paper.journal, user, :admin)
      get :index, format: :json
      json = JSON.parse(response.body)
      expect(json['papers'].size).to eq 0
    end

    context 'meta data' do
      it 'returns meta data about the results' do
        FactoryGirl.create(:paper, :submitted, journal: journal)
        get :index, format: :json
        json = JSON.parse(response.body)
        expect(json['meta']).to be_truthy
        expect(json['meta']['page']).to be_truthy
        expect(json['meta']['totalCount']).to be_truthy
        expect(json['meta']['perPage']).to be_truthy
      end

      it 'meta[page] is 1 when not sent in params' do
        FactoryGirl.create(:paper, :submitted, journal: journal)
        get :index, format: :json
        json = JSON.parse(response.body)
        expect(json['meta']['page']).to eq(1)
      end

      it 'meta[page] is eq to param[page]' do
        FactoryGirl.create(:paper, :submitted, journal: journal)
        get :index, format: :json, page: 7
        json = JSON.parse(response.body)
        expect(json['meta']['page']).to eq(7)
      end

      it 'returns per_page info needed for client pagination' do
        FactoryGirl.create(:paper, :submitted, journal: journal)
        get :index, format: :json
        json = JSON.parse(response.body)
        expect(json['meta']['perPage']).to eq(per_page)
        # note: param-based per page not yet implemented
        # so we use default kaminari config
      end

      context 'when num matching papers is less than default per page' do
        it 'paper numbers and totalPages are the same and correct ' do
          count = per_page - 1
          count.times { make_matchable_paper }
          get :index, format: :json
          json = JSON.parse(response.body)
          expect(json['papers'].count).to eq(count)
          expect(json['meta']['totalCount']).to eq(count)
        end
      end

      context 'when num matching papers is more than default per page' do
        it 'returns the per page num of papers, totalCount matches total' do
          count = per_page + 1
          count.times { make_matchable_paper }
          get :index, format: :json
          json = JSON.parse(response.body)
          expect(json['papers'].count).to eq(per_page)
          expect(json['meta']['totalCount']).to eq(count)
        end
      end
    end

    context 'when search query (simple) is sent in params' do
      it 'properly detects when its meant as a title,
          returns nothing when no match' do
        make_matchable_paper title: 'no can find'
        get :index, format: :json, query: 'please find'
        json = JSON.parse(response.body)
        expect(Paper.count).to eq 1
        expect(json['papers'].count).to eq 0
      end

      it 'properly detects when its meant as a title,
          returns good match' do
        make_matchable_paper title: 'tin roof blues'
        get :index, format: :json, query: 'tin roof blues' # not fuzzy
        json = JSON.parse(response.body)
        expect(Paper.count).to eq 1
        expect(json['papers'].count).to eq 1
        expect(json['papers'].first['title']).to eq 'tin roof blues'
      end

      it 'allows title text to be fuzzy' do
        make_matchable_paper title: 'making friends'
        get :index, format: :json, query: 'friend make' # fuzzy
        json = JSON.parse(response.body)
        expect(Paper.count).to eq 1
        expect(json['papers'].count).to eq 1
        expect(json['papers'].first['title']).to eq 'making friends'
      end

      it 'properly detects when its meant as a DOI,
          returns nothing when no match' do
        make_matchable_paper(title: 'title 123', doi: '456')
        get :index, format: :json, query: '123'
        json = JSON.parse(response.body)
        expect(Paper.count).to eq 1
        expect(json['papers'].count).to eq 0
      end

      it 'properly detects when its meant as a DOI, results are good' do
        make_matchable_paper(title: 'title 123', doi: 'PPREFIX1/journal.JPREFIX1.10001')
        get :index, format: :json, query: '10001'
        json = JSON.parse(response.body)
        expect(Paper.count).to eq 1
        expect(json['papers'].count).to eq 1
        expect(json['papers'].first['manuscript_id']).to eq Paper.first.manuscript_id
      end

      it 'respects pagination when there are more matches than per_page' do
        (per_page + 1).times { make_matchable_paper(title: 'foo') }
        get :index, format: :json, query: 'foo'
        json = JSON.parse(response.body)
        expect(Paper.count).to eq(per_page + 1)
        expect(json['papers'].count).to eq per_page
      end
    end

    context 'when order param is sent with request' do
      it 'orders the results via orderBy' do
        make_matchable_paper(title: 'aaa foo')
        make_matchable_paper(title: 'bbb foo')
        make_matchable_paper(title: 'aaa foo')
        get :index, format: :json, query: 'foo', orderBy: 'title'
        json = JSON.parse(response.body)
        expect(Paper.count).to eq(3)
        expect(json['papers'][0]['title']).to eq('aaa foo')
        expect(json['papers'][1]['title']).to eq('aaa foo')
        expect(json['papers'][2]['title']).to eq('bbb foo')
      end

      it 'orders the results by orderDir when sent' do
        make_matchable_paper(title: 'aaa foo')
        make_matchable_paper(title: 'bbb foo')
        make_matchable_paper(title: 'aaa foo')
        get :index,
            format: :json,
            query: 'foo',
            orderBy: 'title',
            orderDir: 'desc'
        json = JSON.parse(response.body)
        expect(Paper.count).to eq(3)
        expect(json['papers'][0]['title']).to eq('bbb foo')
        expect(json['papers'][1]['title']).to eq('aaa foo')
        expect(json['papers'][2]['title']).to eq('aaa foo')
      end
    end
  end

  def make_matchable_paper(attrs = {})
    FactoryGirl.create(
      :paper,
      :submitted,
      attrs.reverse_merge(journal: journal)
    ).tap do |paper|
      user.assign_to!(
        assigned_to: paper.journal,
        role: paper.journal.staff_admin_role
      )
    end
  end
end
