class GithubProject < ApplicationRecord
  belongs_to :github_auth_user
  has_many :github_project_statuses, dependent: :destroy
  has_many :github_project_types, dependent: :destroy
  has_many :github_user_mappings, dependent: :destroy
  has_one :github_field_mapping, dependent: :destroy
  belongs_to :github_repository, optional: true
  has_many :github_project_priorities, dependent: :destroy
  validates :name, presence: true, uniqueness: true
end
