class GithubRepository < ApplicationRecord
  belongs_to :github_auth_user

  validates :name, presence: true
end
