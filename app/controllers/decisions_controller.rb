class DecisionsController < ApplicationController
  before_action :authenticate_user!
  respond_to :json

  def index
    decisions = Decision.where(paper_id: params[:paper_id])

    render json: decisions, each_serializer: DecisionSerializer, root: 'decisions'
  end

  def show
    render json: Decision.find(params[:id]),
           serializer: DecisionSerializer, root: 'decision'
  end

  def update
    assert !decision.registered_at, "The decision has already been registered"

    decision.update! decision_params
    render json: decision, serializer: DecisionSerializer, root: 'decision'
  end

  def register # I expect a task_id param, too!
    requires_user_can(:register_decision, decision.paper)
    assert decision.paper.awaiting_decision?, "The paper must be submitted"
    assert decision.verdict.present?, "You must pick a verdict, first"

    task = Task.find(params[:task_id])
    # These lines let us update the task/paper in the requester's browser
    # without having to serialize the task along with the decision
    task.notify_requester = true
    task.paper.notify_requester = true
    decision.register!(task)

    Activity.decision_made! decision, user: current_user

    render json: decision.paper.decisions,
           each_serializer: DecisionSerializer,
           root: 'decisions'
  end

  def rescind
    requires_user_can(:rescind_decision, decision.paper)
    assert decision.rescindable?, "That decision is not rescindable"

    decision.paper.notify_requester = true
    decision.rescind!

    render json: decision.paper.decisions,
           each_serializer: DecisionSerializer,
           root: 'decisions'
  end

  private

  def decision
    @decision ||= Decision.includes(:paper).find(params[:id])
  end

  def decision_params
    params.require(:decision).permit(:verdict, :letter, :author_response)
  end
end
