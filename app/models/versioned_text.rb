class VersionedText < ActiveRecord::Base
  belongs_to :paper

  belongs_to :submitting_user, class_name: "User"

  before_update :minor_version!, if: :must_copy

  scope :active, -> { where(active: true) }

  # Called on paper sumbission and resubmission.
  def major_version!(submitting_user)
    update!(major_version: (major_version + 1),
            minor_version: 0,
            copy_on_edit: true,
            submitting_user: submitting_user)
  end

  def must_copy
    copy_on_edit && !copy_on_edit_changed?
  end

  # Make a copy and increment the minor version if the copy_on_edit
  # flag is true.
  def minor_version!
    self.copy_on_edit = false

    old_version = dup
    old_version.text = text_was
    old_version.active = false
    old_version.save!

    self.minor_version = minor_version + 1
  end

  def version_string
    "#{major_version}.#{minor_version}"
  end
end