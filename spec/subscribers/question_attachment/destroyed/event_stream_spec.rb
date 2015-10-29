require 'rails_helper'

describe QuestionAttachment::Destroyed::EventStream do
  include EventStreamMatchers

  let(:pusher_channel) { mock_delayed_class(TahiPusher::Channel) }
  let(:question_attachment) { FactoryGirl.build(:question_attachment_with_task_owner) }

  it "serializes question_attachment id down the system channel on destruction" do
    expect(pusher_channel).to receive_push(payload: hash_including(:ids), down: 'system', on: 'destroyed')
    described_class.call("tahi:question_attachment:destroyed", { action: "destroyed", record: question_attachment })
  end

end