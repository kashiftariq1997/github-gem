class GithubController < ApplicationController
  def import_page
    @repositories = github_current_user&.github_repositories
  end

  def import
    unless github_current_user
      redirect_to root_path, alert: "Authenticate first to continue."
      return
    end
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

  def fetch_issues
    repo = GithubRepository.find(params[:repository_id])
    client = GithubClient.new(github_current_user.access_token)

    issues_response = client.execute_query(
      GithubQueries::ISSUES_QUERY,
      repositoryName: repo.name,
      owner: github_current_user.username
    )

    if issues_response && issues_response['data']
      issues = issues_response&.dig('data', 'repository', 'issues', 'nodes')

      if issues.present?
        issues.each do |issue_data|
          repo.github_issues.find_or_create_by!(
            number: issue_data['number']
          ) do |issue|
            issue.title = issue_data['title']
            issue.body = issue_data['body']
            issue.state = issue_data['state']
            issue.html_url = issue_data['url']
          end
        end
      else
        Rails.logger.info "No issues found for repository: #{repo.name}"
      end
    else
      Rails.logger.error "Failed to fetch issues for repository: #{repo.name}"
    end
  end
end
