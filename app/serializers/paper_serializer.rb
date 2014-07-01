class PaperSerializer < ActiveModel::Serializer
  attributes :id, :short_title, :title, :body, :submitted, :paper_type, :status

  %i(phases figures author_groups supporting_information_files).each do |relation|
    has_many relation, embed: :ids, include: true
  end

  %i(assignees editors reviewers).each do |relation|
    has_many relation, embed: :ids, include: true, root: :users
  end

  has_many :tasks, embed: :ids, polymorphic: true
  has_one :journal, embed: :ids, include: true

  def status
    object.manuscript.try(:status)
  end

  def editors
    object.editors.includes(:affiliations)
  end

  def reviewers
    object.reviewers.includes(:affiliations)
  end
end
