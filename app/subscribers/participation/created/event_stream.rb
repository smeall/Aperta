class Participation::Created::EventStream < EventStreamSubscriber

  def channel
    private_channel_for(record.task.paper)
  end

  def payload
    ParticipationSerializer.new(record).as_json
  end

end