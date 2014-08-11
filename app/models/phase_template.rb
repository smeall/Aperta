class PhaseTemplate < ActiveRecord::Base
  belongs_to :manuscript_manager_template, inverse_of: :phase_templates
  has_many :task_templates, inverse_of: :phase_template

  validates :name, uniqueness: { scope: :manuscript_manager_template_id }
end
