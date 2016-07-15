require 'rails_helper'

describe DecisionsController do
  let(:user) { FactoryGirl.build(:user) }

  let(:paper) do
    FactoryGirl.create(:paper, :submitted_lite)
  end

  describe "#update" do
    let(:new_letter) { "Positive Words in a Letter" }
    let(:new_verdict) { "accept" }
    let(:decision) { paper.draft_decision }

    subject(:do_request) do
      put :update,
          format: :json,
          id: decision.id,
          decision: {
            letter: new_letter,
            verdict: new_verdict
          }
    end

    it_behaves_like "an unauthenticated json request"

    context "a user is logged in" do
      before do
        stub_sign_in(user)
      end

      it "updates the decision object" do
        do_request
        decision.reload
        expect(decision.letter).to eq(new_letter)
        expect(decision.verdict).to eq(new_verdict)
      end

      context "the decision is registered" do
        before do
          decision.update(registered_at: DateTime.now.utc)
        end

        it "Returns a 422" do
          do_request
          expect(response.status).to be(422)
          expect(res_body['errors'][0])
            .to eq("The decision has already been registered")
        end
      end
    end
  end

  describe "#register" do
    subject(:do_request) do
      put :register,
          format: :json,
          id: decision.id,
          task_id: task.id
    end

    let(:decision) { paper.draft_decision }
    let(:task) do
      dub = double("Task", id: 3, paper: paper)
      allow(dub).to receive(:after_register)
      allow(dub).to receive(:notify_requester=)
      dub
    end

    before do
      paper.update(publishing_state: "submitted")
      decision.update(verdict: "accept")
    end

    it_behaves_like "an unauthenticated json request"

    context "a user is logged in who may not register decisions" do
      before do
        allow(user).to receive(:can?)
          .with(:register_decision, paper)
          .and_return false

        stub_sign_in(user)
      end

      it "returns a 403" do
        do_request
        expect(response.status).to be(403)
      end
    end

    context "when a user is logged in who may register decisions" do
      before do
        allow(user).to receive(:can?)
          .with(:register_decision, paper)
          .and_return true

        stub_sign_in(user)

        allow(Task).to receive(:find).with(task.id).and_return(task)
      end

      it "tells the task to register the decision" do
        expect(task).to receive(:after_register)
        do_request
      end

      it "renders the registered decision" do
        do_request
        expect(response.status).to be(200)
        expect(res_body.keys).to include('decisions')
      end

      it "posts to the activity stream" do
        expected_activity_1 = {
          message: "A decision was sent to the author",
          feed_name: "manuscript"
        }
        expected_activity_2 = {
          message: "A decision was made: Accept",
          feed_name: "workflow"
        }
        expected_activity_3 = {
          message: "Paper state changed to submitted",
          feed_name: "forensic"
        }
        expect(Activity).to receive(:create).with hash_including(expected_activity_1)
        expect(Activity).to receive(:create).with hash_including(expected_activity_2)
        expect(Activity).to receive(:create).with hash_including(expected_activity_3)
        do_request
      end

      context "the paper is unsubmitted" do
        before do
          paper.update(publishing_state: "unsubmitted")
        end

        it "Returns a 422" do
          do_request
          expect(response.status).to be(422)
          expect(res_body['errors'][0]).to eq("The paper must be submitted")
        end
      end

      context "the decision has no verdict" do
        before do
          decision.update(verdict: nil)
        end

        it "Returns a 422" do
          do_request
          expect(response.status).to be(422)
          expect(res_body['errors'][0]).to eq("You must pick a verdict, first")
        end
      end
    end
  end

  describe "#rescind" do
    subject(:do_request) do
      put :rescind,
          format: :json,
          id: decision.id
    end
    let(:decision) { paper.draft_decision }
    let(:paper) { FactoryGirl.create(:paper, :rejected_lite) }

    it_behaves_like "an unauthenticated json request"

    context "a user is logged in who may not rescind decisions" do
      before do
        allow(user).to receive(:can?)
          .with(:rescind_decision, paper)
          .and_return false

        stub_sign_in(user)
      end

      it "returns a 403" do
        do_request
        expect(response.status).to be(403)
      end
    end

    context "and the user is signed in" do
      before do
        allow(user).to receive(:can?)
          .with(:rescind_decision, paper)
          .and_return true
        stub_sign_in(user)
      end

      context "and the decision is rescindable" do
        before do
          decision.update(verdict: "reject", registered_at: DateTime.now.utc, minor_version: 0, major_version: 0)
        end

        it "completes successfully" do
          do_request
          expect(response.status).to eq(200)
        end

        it "rescinds the latest decision" do
          do_request
          expect(paper.reload.publishing_state).to eq("initially_submitted")
          expect(decision.reload.rescinded).to be(true)
        end
      end

      context "the decision is not rescindable" do
        before do
          decision.update(registered_at: DateTime.now.utc)
        end

        it "Returns a 422" do
          do_request
          expect(response.status).to be(422)
          expect(res_body['errors'][0]).to eq("That decision is not rescindable")
        end
      end
    end
  end
end
