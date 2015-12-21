class UploadManuscriptNamespace < ActiveRecord::Migration
  # there are incorrect queries in this migration.  look to the next one for corrections.
  def up
    execute <<-SQL
    UPDATE tasks SET type = 'TahiStandardTasks::UploadManuscriptTask' WHERE type = 'UploadManuscript::UploadManuscriptTask';
    UPDATE journal_task_types SET kind = 'TahiStandardTasks::UploadManuscriptTask' WHERE kind = 'UploadManuscript::UploadManuscriptTask';
    SQL
  end

  def down
    execute <<-SQL
    UPDATE tasks SET type = 'UploadManuscript::UploadManuscriptTask' WHERE type = 'TahiStandardTasks::UploadManuscriptTask';
    UPDATE journal_task_types SET kind = 'UploadManuscript::UploadManuscriptTask' WHERE kind = 'TahiStandardTasks::UploadManuscriptTask';
    SQL
  end
end