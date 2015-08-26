class PlosAuthors::PlosAuthor::Created::EventStream < EventStreamSubscriber

  def channel
    record.paper
  end

  def payload
    PlosAuthors::PlosAuthorsSerializer.new(record.plos_authors_task.plos_authors).to_json
  end

end
