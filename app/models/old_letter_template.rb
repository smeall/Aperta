class OldLetterTemplate
  attr_reader :salutation, :body

  def initialize(salutation:, body:)
    @salutation = salutation
    @body = body
  end

  def as_json(_options = nil)
    { salutation: salutation, body: body }
  end

  def to_json
    as_json.to_json
  end
end
