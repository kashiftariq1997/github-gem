class CreateGithubAuthUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :github_auth_users do |t|
      t.string :github_uid
      t.string :username
      t.string :email
      t.string :access_token

      t.timestamps
    end
  end
end
