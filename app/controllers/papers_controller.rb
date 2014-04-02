class PapersController < ApplicationController
  before_filter :authenticate_user!

  def show
    @paper = PaperPolicy.new(params[:id], current_user).paper
    raise ActiveRecord::RecordNotFound unless @paper
    redirect_to edit_paper_path(@paper) unless @paper.submitted?
    @tasks = TaskPolicy.new(@paper, current_user).tasks
  end

  def new
    @paper = Paper.new
  end

  def create
    @paper = current_user.papers.new(paper_params)

    if @paper.save
      redirect_to edit_paper_path @paper
    else
      render :new
    end
  end

  def edit
    @paper = PaperPolicy.new(params[:id], current_user).paper
    redirect_to paper_path(@paper) if @paper.submitted?
    @tasks = TaskPolicy.new(@paper, current_user).tasks
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

    manuscript_data = OxgarageParser.parse(params[:upload_file].path)
    @paper.update manuscript_data
    redirect_to edit_paper_path(@paper)
  end

  def download
    @paper = PaperPolicy.new(params[:id], current_user).paper

    EpubConverter.generate_epub(@paper, current_user) do |epub_stream, epub_name|
      send_data epub_stream.string, filename: epub_name, disposition: 'attachment'
    end
  end

  private

  def paper_params
    params.require(:paper).permit(:short_title, :title, :abstract, :body, :paper_type, :submitted, :journal_id, declarations_attributes: [:id, :answer], authors: [:first_name, :last_name, :affiliation, :email])
  end
end
