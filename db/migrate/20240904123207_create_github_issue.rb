class CreateGithubIssue < ActiveRecord::Migration[7.1]
  create_table :github_issues do |t|
    t.string :title
    t.text :description
    t.string :state
    t.string :html_url
    t.integer :number
    t.integer :codegiant_task_id
    t.references :github_repository, null: false, foreign_key: true

    t.timestamps
  end
end
