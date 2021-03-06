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

class ReviewerReportTaskCreator
  attr_accessor :originating_task, :paper, :assignee

  def initialize(originating_task:, assignee_id:)
    @originating_task = originating_task
    @paper = originating_task.paper
    @assignee = User.find(assignee_id)
  end

  def process
    paper.transaction do
      assign_paper_role!
      find_or_create_related_task
    end
  end

  private

  def find_or_create_related_task
    if existing_reviewer_report_task.blank?
      @task = reviewer_report_task_class.create!(
        paper: paper,
        phase: default_phase,
        title: "Review by #{assignee.full_name}"
      )
      assignee.assign_to!(assigned_to: @task, role: paper.journal.reviewer_report_owner_role)
      create_reviewer_report

      @task
    else
      assignee.assign_to!(assigned_to: existing_reviewer_report_task,
                          role: paper.journal.task_participant_role)
      existing_reviewer_report_task.tap(&:incomplete!)
      @task = existing_reviewer_report_task
    end
  end

  def create_reviewer_report
    ReviewerReport.create!(
      task: @task,
      decision: @paper.draft_decision,
      user: assignee,
    ).accept_invitation!
  end

  def reviewer_report_task_class
    if @paper.front_matter?
      TahiStandardTasks::FrontMatterReviewerReportTask
    else
      TahiStandardTasks::ReviewerReportTask
    end
  end

  def existing_reviewer_report_task
    @existing_reviewer_report_task ||= begin
      reviewer_report_task_class.joins(assignments: :role).where(
        paper_id: @paper.id,
        assignments: {
          role_id: @paper.journal.reviewer_report_owner_role,
          user_id: assignee.id
        }
      ).first
    end
  end

  # Multiple assignees can exist on `paper` as a reviewer
  def assign_paper_role!
    assignee.assign_to!(assigned_to: paper, role: paper.journal.reviewer_role)
  end

  def default_phase
    paper.phases.where(name: 'Get Reviews').first || originating_task.phase
  end
end
