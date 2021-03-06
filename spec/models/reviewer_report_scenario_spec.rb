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
# rubocop:disable Metrics/BlockLength
describe ReviewerReportScenario do
  subject(:context) { ReviewerReportScenario.new(reviewer_report) }

  describe 'rendering' do
    let(:reviewer_report) { FactoryGirl.create(:reviewer_report) }

    it 'renders the due date' do
      due_at = 2.weeks.from_now.to_s(:due_with_hours)
      reviewer_report.due_datetime = DueDatetime.new(due_at: due_at)
      source = '{{ review.due_at }}'
      expect(LetterTemplate.new(body: source).render(context).body).to eq(due_at)
    end

    it 'renders the journal name' do
      journal = reviewer_report.paper.journal
      source = '{{ journal.name }}'
      expect(LetterTemplate.new(body: source).render(context).body).to eq(journal.name)
    end

    it 'renders the reviewer last name' do
      reviewer = reviewer_report.user
      source = '{{ reviewer.last_name }}'
      expect(LetterTemplate.new(body: source).render(context).body).to eq(reviewer.last_name)
    end

    it 'renders the reviewer email' do
      reviewer = reviewer_report.user
      source = '{{ reviewer.email }}'
      expect(LetterTemplate.new(body: source).render(context).body).to eq(reviewer.email)
    end

    it 'renders the paper title' do
      paper = reviewer_report.paper
      source = '{{ manuscript.title }}'
      expect(LetterTemplate.new(body: source).render(context).body).to eq(paper.title)
    end
  end
end
