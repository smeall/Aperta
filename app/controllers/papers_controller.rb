class PapersController < ApplicationController
  before_filter :authenticate_user!

  def show
    @paper = current_paper || submitted_paper_for_admin
    raise ActiveRecord::RecordNotFound unless @paper
    redirect_to edit_paper_path(@paper) unless @paper.submitted?
  end

  def new
    @paper = Paper.new
  end

  def create
    @paper = current_user.papers.new(paper_params)

    if @paper.save
      redirect_to edit_paper_path @paper
    end
  end

  def edit
    @paper = Paper.find(params[:id])
    redirect_to paper_path(@paper) if @paper.submitted?
  end

  def update
    @paper = Paper.find(params[:id])
    params[:paper][:authors] = JSON.parse params[:paper][:authors] if params[:paper].has_key? :authors

    if @paper.update paper_params
      respond_to do |f|
        f.html { redirect_to root_path }
        f.json { head :no_content }
      end
    end
  end

  def upload
    @paper = Paper.find(params[:id])

    manuscript_data = DocumentParser.parse(params[:upload_file].path)
    @paper.update manuscript_data
    redirect_to edit_paper_path(@paper)
  end

  private

  def submitted_paper_for_admin
    Paper.where(id: params[:id], submitted: true).first if current_user.admin?
  end

  def current_paper
    current_user.papers.where(id: params[:id]).first
  end

  def paper_params
    params.require(:paper).permit(:short_title, :title, :abstract, :body, :paper_type, :submitted, declarations_attributes: [:id, :answer], authors: [:first_name, :last_name, :affiliation, :email])
  end
end
