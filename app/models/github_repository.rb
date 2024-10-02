class GithubRepository < ApplicationRecord
  belongs_to :github_auth_user
  has_many :github_issues, dependent: :destroy
  has_one :github_project, dependent: :destroy
  validates :name, presence: true
end
