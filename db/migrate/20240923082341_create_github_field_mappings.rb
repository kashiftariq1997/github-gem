class CreateGithubFieldMappings < ActiveRecord::Migration[7.1]
  def change
    create_table :github_field_mappings do |t|
      t.json :mapping, default: {}, null: false  # JSON column for storing mappings
      t.bigint :github_project_id, null: false   # Foreign key to the github_project
      t.timestamps  # Adds created_at and updated_at
    end
    add_index :github_field_mappings, :github_project_id
  end
end
