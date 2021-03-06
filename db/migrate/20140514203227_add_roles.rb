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

class AddRoles < ActiveRecord::Migration
  def up
    create_table :roles do |t|
      t.string :name
      t.boolean :admin, null: false, default: false
      t.boolean :editor, null: false, default: false
      t.boolean :reviewer, null: false, default: false

      t.references :journal

      t.timestamps
    end

    add_column :journal_roles, :role_id, :integer
    add_index :journal_roles, :role_id

    remove_column :journal_roles, :editor
    remove_column :journal_roles, :admin
    remove_column :journal_roles, :reviewer
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
