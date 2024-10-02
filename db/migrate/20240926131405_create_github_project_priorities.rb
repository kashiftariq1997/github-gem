class CreateGithubProjectPriorities < ActiveRecord::Migration[7.1]
  def change
    create_table :github_project_priorities do |t|
      t.integer :github_project_id
      t.integer :priority_id
      t.string :title

      t.timestamps
    end
  end
end
