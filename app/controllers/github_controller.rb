class GithubController < ApplicationController
  def import_page
    @repositories = github_current_user&.github_repositories
  end

  def import
    client = GithubClient.new(github_current_user.access_token)
    response = client.execute_query(GithubQueries::REPOSITORIES_QUERY, login: github_current_user.username)

    if response && response['data']
      repositories = response['data']['user']['repositories']['nodes']
      repositories.each do |repo_data|
        repo = github_current_user.github_repositories.find_or_create_by!(
          name: repo_data['name'],
          github_auth_user: github_current_user
        ) do |repo|
          repo.description = repo_data['description']
          repo.url = repo_data['url']
        end
      end

      redirect_to github_import_page_path, notice: "Repositories and Issues Imported!"
    else
      redirect_to github_import_page_path, alert: "Failed to import repositories."
    end
  end
end
