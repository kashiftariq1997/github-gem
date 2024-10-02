class CreateGithubUserMappings < ActiveRecord::Migration[7.1]
  def change
    create_table :github_user_mappings do |t|
      t.references :github_user, null: false, foreign_key: { to_table: :github_users }
      t.references :github_codegiant_user, null: false, foreign_key: { to_table: :github_codegiant_users }
      t.references :github_project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
