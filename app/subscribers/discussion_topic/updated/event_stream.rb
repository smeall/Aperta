class DiscussionTopic::Updated::EventStream < EventStreamSubscriber

  def channel
    private_channel_for(record)
  end

  def payload
    DiscussionTopicSerializer.new(record).as_json
  end

end