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

require 'rails_helper'

describe DecisionsController do
  let(:user) { FactoryGirl.build(:user) }
  let(:paper) { FactoryGirl.create(:paper, :submitted_lite) }
  let!(:revise_manuscript_task) { create :revise_task, paper: paper }

  describe '#index' do
    let(:paper) { FactoryGirl.create(:paper) }
    let!(:decision_1) { FactoryGirl.create(:decision, paper: paper) }
    let!(:decision_2) { FactoryGirl.create(:decision, :pending, paper: paper) }

    subject(:do_request) do
      xhr :get, :index, format: :json, paper_id: paper.id
    end

    it_behaves_like 'an unauthenticated json request'

    context 'when the user is authorized to :view the paper' do
      let(:decisions_in_response) do
        res_body.with_indifferent_access[:decisions]
      end
      let(:decision_ids_in_response) do
        decisions_in_response.map { |h| h[:id] }
      end

      before do
        stub_sign_in user
        allow(user).to receive(:can?)
          .with(:view, paper)
          .and_return true
        allow(user).to receive(:can?)
          .with(:view_decisions, paper)
          .and_return false
      end

      it 'includes only completed decisions in the response' do
        do_request
        expect(decision_ids_in_response).to contain_exactly(decision_1.id)
      end

      context 'and the user can also :view_decisions on the paper' do
        before do
          allow(user).to receive(:can?)
            .with(:view_decisions, paper)
            .and_return true
        end

        it 'includes all decisions in the response' do
          do_request
          expect(decision_ids_in_response).to contain_exactly(
            decision_1.id,
            decision_2.id
          )
        end
      end

      it 'responds with decision fields' do
        do_request

        data = res_body.with_indifferent_access
        expect(data).to have_key(:decisions)

        decision_json = decisions_in_response[0]
        expect(decision_json).to have_key(:author_response)
        expect(decision_json).to have_key(:draft)
        expect(decision_json).to have_key(:major_version)
      end

      it { is_expected.to responds_with(200) }
    end

    context 'when the user does not have access to :view the paper' do
      before do
        stub_sign_in user
        allow(user).to receive(:can?)
          .with(:view, paper)
          .and_return false
      end

      it { is_expected.to responds_with(403) }
    end
  end

  describe '#show' do
    let(:decision) { paper.draft_decision }

    subject(:do_request) do
      xhr :get, :show, format: :json, id: decision.id
    end

    it_behaves_like 'an unauthenticated json request'

    context 'when the user is authorized' do
      before do
        stub_sign_in user
        allow(user).to receive(:can?).with(:view_decisions, paper).and_return true
        allow(user).to receive(:can?).with(:view, paper).and_return true
        allow(user).to receive(:can?).with(:view, paper.revise_task).and_return true
        do_request
      end

      it 'returns decision fields' do
        expect(response.status).to eq(200)

        data = res_body.with_indifferent_access
        expect(data).to have_key(:decision)

        decision_json = data[:decision]
        expect(decision_json).to have_key(:author_response)
        expect(decision_json).to have_key(:draft)
        expect(decision_json).to have_key(:major_version)
      end
    end

    context 'when the user does not have access' do
      before do
        stub_sign_in user
        allow(user).to receive(:can?)
          .with(:view_decisions, paper)
          .and_return false
        allow(user).to receive(:can?)
          .with(:view, paper.revise_task)
          .and_return false
      end

      it { is_expected.to responds_with(403) }
    end
  end

  describe "#update" do
    let(:decision) { paper.draft_decision }
    subject(:do_request) do
      put :update,
          format: :json,
          id: decision.id,
          decision: {}
    end

    it_behaves_like "an unauthenticated json request"

    context "a user is logged in" do
      before do
        stub_sign_in(user)
      end

      context 'and has no permissions' do
        let(:do_request) do
          put :update,
              format: :json,
              id: decision.id
        end

        it 'returns a 403' do
          do_request
          expect(response.status).to eq 403
        end
      end

      describe "updating the author response" do
        let(:author_response) { Faker::Lorem.paragraph(2) }
        subject(:do_request) do
          put :update,
              format: :json,
              id: decision.id,
              decision: {
                author_response: author_response
              }
        end

        context "the decision has been registered" do
          before do
            decision.update(registered_at: DateTime.now.utc,
                            major_version: 0,
                            minor_version: 0)
          end

          shared_examples_for "the author response is editable" do
            it "Updates the decision's author_response" do
              expect do
                do_request
                expect(response.status).to eq 204
              end.to change { decision.reload.author_response }.from(decision.author_response).to(author_response)
            end
          end

          context "the user has the permission to edit the ReviseManuscriptTask" do
            before do
              allow(user).to receive(:can?).with(:register_decision, paper).and_return(false)
              allow(user).to receive(:can?).with(:edit, revise_manuscript_task).and_return(true)
            end

            it_behaves_like "the author response is editable"

            # Testing this case because of the additive nature of permission granting in DecisionsController#update
            context "the user also has the permission to register a decision" do
              before do
                allow(user).to receive(:can?).with(:register_decision, paper).and_return(true)
              end

              it_behaves_like "the author response is editable"
            end
          end

          context "but the user does not have the permission to edit the ReviseManuscriptTask" do
            it "does not update the author_response" do
              expect do
                do_request
              end.not_to change { decision.reload.author_response }
              expect(response.status).to eq 403
            end
          end
        end
      end

      describe "updating the letter and verdict" do
        let(:new_letter) { Faker::Lorem.paragraph(2) }
        let(:new_verdict) { "accept" }
        subject(:do_request) do
          put :update,
              format: :json,
              id: decision.id,
              decision: {
                letter: new_letter,
                verdict: new_verdict
              }
        end

        context "the user has the permission to register a decision" do
          before do
            allow(user).to receive(:can?).with(:register_decision, paper).and_return(true)
            allow(user).to receive(:can?).with(:edit, revise_manuscript_task).and_return(false)
          end

          context "the decision is not registered" do
            it "updates the decision object" do
              expect do
                do_request
                decision.reload
              end.to change { [decision.letter, decision.verdict] }.to([new_letter, new_verdict])
            end
          end

          context "the decision is registered" do
            before do
              decision.update(registered_at: DateTime.now.utc, major_version: 0, minor_version: 0)
            end

            it "Returns a 422 and doesn't update the model" do
              expect do
                do_request
                decision.reload
              end.not_to change { [decision.verdict, decision.letter] }
              expect(response.status).to eq 422
              expect(res_body).to have(1).errors_on(:letter)
              expect(res_body).to have(1).errors_on(:verdict)
            end
          end
        end

        context "the user does not have the permission to register a decision" do
          it "does not update the letter or verdict" do
            expect do
              do_request
              decision.reload
            end.not_to change { [decision.verdict, decision.letter] }
            expect(response.status).to eq 403
          end
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
      double("AdHocTask", id: 3, paper: paper).tap do |t|
        allow(t).to receive(:after_register)
        allow(t).to receive(:notify_requester=)
        allow(t).to receive(:answer_for)
        allow(t).to receive(:send_email)
      end
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
        allow(user).to receive(:can?).with(:register_decision, paper).and_return true
        allow(user).to receive(:can?).with(:view, paper).and_return true

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
        expect(Activity).to receive(:create).with hash_including(
          message: "A decision was made: Accept",
          feed_name: "manuscript"
        )
        expect(Activity).to receive(:create!).with hash_including(
          message: "Paper state changed to accepted",
          feed_name: "forensic"
        )
        do_request
      end

      describe "email" do
        it "is sent" do
          expect(task).to receive(:send_email)
          do_request
        end
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
        allow(user).to receive(:can?).with(:rescind_decision, paper).and_return true
        allow(user).to receive(:can?).with(:view, paper).and_return true
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
          expect(paper.reload.publishing_state).to eq("submitted")
          expect(decision.reload.rescinded).to be(true)
        end

        it "posts to the activity stream" do
          expect(Activity)
            .to(receive(:decision_rescinded!))
            .with(decision, user: user)
          do_request
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
