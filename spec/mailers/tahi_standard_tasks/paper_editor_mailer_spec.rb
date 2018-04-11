require 'rails_helper'

describe TahiStandardTasks::PaperEditorMailer do
  include ClientRouteHelper

  describe "#notify_invited" do
    subject(:email) do
      described_class.notify_invited(invitation_id: invitation.id)
    end

    let(:invitation) do
      FactoryGirl.create(:invitation, body: "Hiya, chief!")
    end

    it "has the correct subject line" do
      expect(email.subject).to eq "You've been invited as an editor for the manuscript, \"#{invitation.task.paper.display_title}\""
    end

    it "has the correct body content" do
      expect(email.body).to include invitation.body
    end

    it "sends the email to the invitee's email" do
      expect(email.to).to contain_exactly(invitation.email)
    end

    it "contains a link to the dashboard" do
      expect(email.body.raw_source).to match(%r{http://www.example.com/})
    end

    it "attaches attachments on the invitation" do
      invitation.attachments << FactoryGirl.build(
        :invitation_attachment,
        file: File.open(Rails.root.join("spec/fixtures/bill_ted1.jpg"))
      )
      invitation.attachments << FactoryGirl.build(
        :invitation_attachment,
        file: File.open(Rails.root.join("spec/fixtures/yeti.gif"))
      )

      expect(email.attachments.length).to eq(2)
      expect(email.attachments.map(&:filename)).to contain_exactly(
        "bill_ted1.jpg",
        "yeti.gif"
      )
    end

    describe "links" do
      it "has a link to Aperta's dashboard for accepting the invitation in the email body" do
        expect(email.body).to include client_dashboard_url
      end

      it "has a link to decline the invitation in the email body" do
        expect(email.body).to include
        client_show_invitation_url(token: invitation.token)
      end
    end
  end
end
