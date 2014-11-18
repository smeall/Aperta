require 'spec_helper'

feature 'Message Cards', js: true do
  let(:admin) { create :user, :site_admin, first_name: "Admin" }
  let(:journal) { create(:journal) }
  let(:albert) { create :user, first_name: "Albert" }

  before do
    assign_journal_role(journal, albert, :admin)
    sign_in_page = SignInPage.visit
    sign_in_page.sign_in admin
    paper.paper_roles.build(user: albert, role: PaperRole::COLLABORATOR).save
  end


  let(:paper) do
    FactoryGirl.create(:paper, :with_tasks, creator: admin, submitted: true, journal: journal)
  end

  describe "commenting on an existing message" do
    let(:phase) { paper.phases.first }
    let!(:message) do
      create :message_task, phase: phase, participants: participants
    end
    let!(:initial_comment) { create :comment, commenter: commenter, task: message }

    context "blank comments" do
      let(:commenter) { admin }
      let(:participants) { [admin] }
      scenario "user can't add any" do
        task_manager_page = TaskManagerPage.visit paper
        task_manager_page.view_card message.title, MessageCardOverlay do |card|
          card.post_message 'Hello'
          card.post_message ''
          expect(card.comments.length).to eq 2
        end
      end
    end

    context "the user is already a participant" do
      let(:commenter) { admin }
      let(:participants) { [admin] }

      scenario "the user can add a commment" do
        task_manager_page = TaskManagerPage.visit paper
        task_manager_page.view_card message.title, MessageCardOverlay do |card|
          expect(card).to have_css('.message-overlay')
          card.post_message 'Hello'
          expect(card).to have_last_comment_posted_by(admin)
        end
      end
    end

    context "the user isn't a participant" do
      let(:commenter) { admin }
      let(:participants) { [albert] }
      scenario "the user does not become a participant after commenting" do
        task_manager_page = TaskManagerPage.visit paper
        task_manager_page.view_card message.title, MessageCardOverlay do |card|
          expect(card).to have_css('.message-overlay')
          card.post_message 'Hello'
          expect(card).to have_participants(albert)
          expect(card).to have_no_participants(admin)
          expect(card).to have_last_comment_posted_by(admin)
        end
      end
    end
  end

  describe "unread comments" do
    let(:comment_count) { 4 }
    let!(:task) { create :message_task, phase: paper.phases.first, participants: [albert, admin] }
    let!(:initial_comments) do
      FactoryGirl.create_list(:comment, comment_count, task: task, commenter: albert)
      CommentLookManager.sync_task(task.reload)
    end

    scenario "displays the number of unread comments as badge on task" do
      page = TaskManagerPage.visit paper
      expect(page.message_tasks.first.unread_comments_badge).to eq comment_count
    end
  end
end
