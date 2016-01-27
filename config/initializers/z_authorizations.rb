Authorizations.configure do |config|
  config.assignment_to(
    Paper,
    authorizes: Task,
    via: :tasks
  )

  config.assignment_to(
    Journal,
    authorizes: Paper,
    via: :papers
  )
end
