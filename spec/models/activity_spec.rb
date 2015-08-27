require 'rails_helper'

describe Activity do
  let(:user){ FactoryGirl.build(:user) }

  describe "#assignment_created!" do
    subject(:activity) { Activity.assignment_created!(paper_role, user: user) }
    let(:paper_role){ FactoryGirl.build(:paper_role, :editor) }

    it {
      is_expected.to have_attributes(
        feed_name: "workflow",
        activity_key: "assignment.created",
        subject: paper_role.paper,
        user: user,
        message: "#{paper_role.user.full_name} was added as Editor"
    )}
  end

  describe "#author_added!" do
    subject(:activity) { Activity.author_added!(plos_author, user: user) }
    let(:plos_author) { FactoryGirl.build(:plos_author) }

    it {
      is_expected.to have_attributes(
        feed_name: "manuscript",
        activity_key: "plos_author.created",
        subject: plos_author.paper,
        user: user,
        message: "Added Author"
    )}
  end

  describe "#comment_created" do
    subject(:activity) { Activity.comment_created!(comment, user: user) }
    let(:comment){ FactoryGirl.build(:comment) }

    it {
      is_expected.to have_attributes(
        feed_name: "workflow",
        activity_key: "commented.created",
        subject: comment.paper,
        user: user,
        message: "A comment was added to #{comment.task.title} card"
    )}
  end

  describe "#decision_made!" do
    subject(:activity) { Activity.decision_made!(decision, user: user) }
    let(:decision) { FactoryGirl.build(:decision) }

    it {
      is_expected.to have_attributes(
        feed_name: "workflow",
        activity_key: "decision.made",
        subject: decision.paper,
        user: user,
        message: "#{decision.verdict.titleize} was sent to author"
      )}
  end

  describe "#invitation_created!" do
    subject(:activity) { Activity.invitation_created!(invitation, user: user) }
    let(:invitation) { FactoryGirl.build(:invitation) }

    it {
      is_expected.to have_attributes(
        feed_name: "workflow",
        activity_key: "invitation.created",
        subject: invitation.paper,
        user: user,
        message: "#{invitation.recipient_name} was invited as #{invitation.task.invitee_role.capitalize}"
    )}
  end

  describe "#invitation_accepted!" do
    subject(:activity) { Activity.invitation_accepted!(invitation, user: user) }
    let(:invitation) { FactoryGirl.build(:invitation) }

    it {
      is_expected.to have_attributes(
        feed_name: "workflow",
        activity_key: "invitation.accepted",
        subject: invitation.paper,
        user: user,
        message: "#{invitation.recipient_name} accepted invitation as #{invitation.task.invitee_role.capitalize}"
    )}
  end

  describe "#invitation_rejected!" do
    subject(:activity) { Activity.invitation_rejected!(invitation, user: user) }
    let(:invitation) { FactoryGirl.build(:invitation) }

    it {
      is_expected.to have_attributes(
        feed_name: "workflow",
        activity_key: "invitation.rejected",
        subject: invitation.paper,
        user: user,
        message: "#{invitation.recipient_name} declined invitation as #{invitation.task.invitee_role.capitalize}"
    )}
  end

  describe "#paper_created!" do
    subject(:activity) { Activity.paper_created!(paper, user: user) }
    let(:paper) { FactoryGirl.build(:paper) }

    it {
      is_expected.to have_attributes(
        feed_name: "manuscript",
        activity_key: "paper.created",
        subject: paper,
        user: user,
        message: "Manuscript was created"
    )}
  end

  describe "#paper_edited!" do
    subject(:activity) { Activity.paper_edited!(paper, user: user) }
    let(:paper) { FactoryGirl.build(:paper) }

    it {
      is_expected.to have_attributes(
        feed_name: "manuscript",
        activity_key: "paper.edited",
        subject: paper,
        user: user,
        message: "Manuscript was edited"
    )}
  end

  describe "#paper_submitted!" do
    subject(:activity) { Activity.paper_submitted!(paper, user: user) }
    let(:paper) { FactoryGirl.build(:paper) }

    it {
      is_expected.to have_attributes(
        feed_name: "manuscript",
        activity_key: "paper.submitted",
        subject: paper,
        user: user,
        message: "Manuscript was sumbitted"
    )}
  end

  describe "#participation_created!" do
    subject(:activity) { Activity.participation_created!(participation, user: user) }
    let(:participation) { FactoryGirl.build(:participation) }

    it {
      is_expected.to have_attributes(
        feed_name: "manuscript",
        activity_key: "participation.created",
        subject: participation.paper,
        user: user,
        message: "Added Contributor: #{participation.user.full_name}"
    )}
  end

  describe "#participation_destroyed!" do
    subject(:activity) { Activity.participation_destroyed!(participation, user: user) }
    let(:participation) { FactoryGirl.build(:participation) }

    it {
      is_expected.to have_attributes(
        feed_name: "manuscript",
        activity_key: "particpation.destroyed",
        subject: participation.paper,
        user: user,
        message: "Removed Contributor: #{participation.user.full_name}"
    )}
  end

  describe "#task_updated!" do
    context "a submission task" do
      subject(:activity) { Activity.task_updated!(task, user: user) }
      let(:task) { FactoryGirl.create(:metadata_task) }

      context "was completed" do
        before { task.update! completed: true }

        it {
          is_expected.to have_attributes(
            feed_name: "manuscript",
            activity_key: "task.completed",
            subject: task.paper,
            user: user,
            message: "#{task.title} card was marked as complete"
        )}
      end

      context "was incompleted" do
        before {
          task.update! completed: true
          task.update! completed: false
        }

        it {
          is_expected.to have_attributes(
            feed_name: "manuscript",
            activity_key: "task.incompleted",
            subject: task.paper,
            user: user,
            message: "#{task.title} card was marked as incomplete"
        )}
      end
    end

    context "a submission task" do
      subject(:activity) { Activity.task_updated!(task, user: user) }
      let(:task) { FactoryGirl.create(:task) }

      context "was completed" do
        before { task.update! completed: true }

        it {
          is_expected.to have_attributes(
            feed_name: "workflow",
            activity_key: "task.completed",
            subject: task.paper,
            user: user,
            message: "#{task.title} card was marked as complete"
        )}
      end

      context "was incompleted" do
        before {
          task.update! completed: true
          task.update! completed: false
        }

        it {
          is_expected.to have_attributes(
            feed_name: "workflow",
            activity_key: "task.incompleted",
            subject: task.paper,
            user: user,
            message: "#{task.title} card was marked as incomplete"
        )}
      end
    end
  end
end
