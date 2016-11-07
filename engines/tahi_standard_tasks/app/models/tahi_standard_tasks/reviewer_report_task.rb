module TahiStandardTasks
  # Note the ReviewerReportTask and its subclasses are used for
  # "ALL REVIEWS COMPLETE" in the paper tracker. If a task is expected to show
  # up in the "ALL REVIEWS COMPLETE" query, it should inherit from
  # ReviewerReportTask.
  class ReviewerReportTask < Task
    DEFAULT_TITLE = 'Reviewer Report'
    DEFAULT_ROLE = 'reviewer'
    SYSTEM_GENERATED = true

    before_create :assign_to_draft_decision
    has_many :decisions, -> { uniq }, through: :paper

    # Overrides Task#restore_defaults to be only restore +old_role+. This
    # will never update +title+ as that is dynamically determined. If you
    # need to change the reviewer report title write a data migration.
    def self.restore_defaults
      update_all(old_role: self::DEFAULT_ROLE)
    end

    # find_or_build_answer_for(...) will return the associated answer for this
    # task given :nested_question. For ReviewerReportTask this enforces the
    # lookup to be scoped to this task's current decision. Answers associated
    # with previous decisions will not be returned.
    #
    # == Optional Parameters
    #  * decision - ignored if provided, always enforces the task's decision.id
    #
    def find_or_build_answer_for(nested_question:, **_kwargs)
      super(
        nested_question: nested_question,
        decision: decision
      )
    end

    def body
      # body is a json column by default which returns an Array. We don't want
      # an array, we want to store properties. So if we get a blank
      # object from the DB then return a Hash instead of the default json Array.
      # Additionally, cache the body so we can set individual properties via
      # calls like "body['foo'] = 'bar'" and have them persist when this
      # task is saved.
      @body ||= begin
        result = super
        result.blank? ? {} : result
      end
    end

    def body=(new_body)
      @body = nil
      super(new_body)
    end

    def can_change?(_)
      !submitted?
    end

    def incomplete!
      assign_to_draft_decision
      update!(
        completed: false,
        body: body.except("submitted")
      )
    end

    # +decision+ returns the _relevant_ decision to this task. This is so
    # the appropriate questions and responses for this task can be determined.
    #
    # This is impacted by the concept of "latest decision" in the app as it's
    # not always the latest rendered decision by an Academic Editor.
    def decision
      paper.decisions.find(body["decision_id"]) if body["decision_id"]
    end

    def decision=(new_decision)
      current_decision_id = body["decision_id"]

      update_body(
        "decision_id" => new_decision.try(:id)
      )
    end

    def submitted?
      !!body["submitted"]
    end

    private

    def assign_to_draft_decision
      self.decision = paper.draft_decision
    end

    def update_body(hsh)
      self.body = body.merge(hsh)
    end
  end
end
