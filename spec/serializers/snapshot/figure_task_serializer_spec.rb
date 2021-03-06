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

describe Snapshot::FigureTaskSerializer do
  subject(:serializer) { described_class.new(task) }
  let(:task) { FactoryGirl.create(:figure_task, paper: paper) }
  let(:figure_1) do
    FactoryGirl.create(
      :figure,
      :with_resource_token,
      title: 'figure 1 title',
      caption: 'figure 1 caption',
    )
  end
  let(:figure_2) do
    FactoryGirl.create(
      :figure,
      :with_resource_token,
      title: 'figure 2 title',
      caption: 'figure 2 caption'
    )
  end

  let(:paper) { FactoryGirl.create(:paper, figures: [figure_1, figure_2]) }

  describe '#as_json' do
    let(:figures_json) do
      serializer.as_json[:children].select do |child_json|
        child_json[:name] == 'figure'
      end
    end

    it 'serializes to JSON' do
      expect(serializer.as_json).to include(
        name: 'figure-task',
        type: 'properties'
      )
    end

    it "serializes the figures for the task's paper" do
      expect(figures_json.length).to be 2

      expect(figures_json[0]).to match hash_including(
        name: 'figure',
        type: 'properties'
      )
      expect(figures_json[0][:children]).to include(
        { name: 'id', type: 'integer', value: figure_1.id },
        { name: 'file', type: 'text', value: figure_1.filename },
        { name: 'file_hash', type: 'text', value: figure_1.file_hash },
        { name: 'title', type: 'text', value: figure_1.title },
        { name: 'url', type: 'url', value: figure_1.non_expiring_proxy_url }
      )

      expect(figures_json[1]).to match hash_including(
        name: 'figure',
        type: 'properties'
      )
      expect(figures_json[1][:children]).to include(
        { name: 'id', type: 'integer', value: figure_2.id },
        { name: 'file', type: 'text', value: figure_2.filename },
        { name: 'file_hash', type: 'text', value: figure_2.file_hash },
        { name: 'title', type: 'text', value: figure_2.title },
        { name: 'url', type: 'url', value: figure_2.non_expiring_proxy_url }
      )
    end

    it_behaves_like 'snapshot serializes related answers as nested questions', resource: :task
  end
end
