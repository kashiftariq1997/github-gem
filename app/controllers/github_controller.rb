class GithubController < ApplicationController
  def import_page
    @repositories = github_current_user&.github_repositories
  end

  def import_repos
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
        project = GithubProject.find_or_create_by!(name: repo_data['name'], github_auth_user: github_current_user)
        project.update!(prefix: '', github_repository_id: repo.id)
        FetchAssigneesJob.perform_now(repo.id, github_current_user.id)
      end

      redirect_to github_import_page_path, notice: "Repositories are Imported!"
    else
      redirect_to github_import_page_path, alert: "Failed to import repositories."
    end
  end

  def fetch_issues
    repo = GithubRepository.find(params[:repository_id])

    FetchIssuesJob.perform_later(repo.id, github_current_user.id) # Run in background
    redirect_to github_edit_repo_path(repo), notice: "Fetching issues for repository #{repo.name}. This may take a few minutes."
  end

  def edit_repo
    @repository = GithubRepository.find(params[:id])
  end

  def create_repo
    repository = GithubRepository.find_by(id: params[:id])
    user_provided_name = params[:github_repository][:name]

    # Get the token from the params
    token = ENV['TOKEN']

    # Enqueue the job with the token and other parameters
    Rails.logger.info("Enqueuing CreateGithubRepositoryJob with name: #{user_provided_name} and token: #{token}")

    CreateGithubRepositoryJob.perform_later(
      token,
      user_provided_name,
      github_current_user.access_token,
      repository.description,
      repository.url,
      github_current_user.username
    )

    flash[:notice] = "Repository creation is in progress!"
    FetchCodegiantUsersJob.perform_now()
    @project = GithubProject.find_by(id: params[:id])
    redirect_to github_projects_path(@project)
  end

end
