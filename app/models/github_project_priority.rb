# app/models/github_project_priority.rb
class GithubProjectPriority < ApplicationRecord
  belongs_to :github_project
end
