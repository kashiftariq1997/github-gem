class GraphqlMutationService
  include HTTParty
  base_uri 'https://codegiant.io/graphql'

  def initialize(token)
    @headers = {
      "Content-Type" => "application/json",
      "Authorization" => "Bearer #{token}"
    }
  end

  # Method to create a repository
  def create_repository(workspace_id:, title:, access_token:, description: nil, import_url: nil, import_url_username: nil, import_url_password: nil, import_url_ssh_key: nil)
    query = <<~GRAPHQL
      mutation createRepository(
        $workspaceId: ID!,
        $title: String!,
        $description: String
      ) {
        createRepository(
          workspaceId: $workspaceId,
          title: $title,
          description: $description
        ) {
          id
          title
          description
          importUrl
          httpUrlToRepo
          sshUrlToRepo
        }
      }
    GRAPHQL

    variables = {
      workspaceId: workspace_id,
      title: title,
      description: description
    }
    response = execute_query(query, variables)
    http_url_to_repo = response["createRepository"]["httpUrlToRepo"]
    pull_and_push_repository(import_url, http_url_to_repo, access_token)
    response
  end

  def create_project(workspace_id:, project_type:, tracking_type:, prefix:, title:)
    query = <<~GRAPHQL
      mutation createProject($workspaceId: ID!, $projectType: String!, $trackingType: String!, $prefix: String!, $title: String!) {
        createProject(workspaceId: $workspaceId, projectType: $projectType, trackingType: $trackingType, prefix: $prefix, title: $title) {
          id
          title
          taskPriorities{
            id
            title
          }
          taskStatuses{
            id
            title
          }
          taskTypes{
            id
            title
            color
            completeTrigger
          }
        }
      }
    GRAPHQL
    variables = { workspaceId: workspace_id, projectType: project_type, trackingType: tracking_type, prefix: prefix, title: title }
    execute_query(query, variables)
  end

  def create_project_task(project_id:, title:, description:, status_id:, priority_id:, type_id:, start_date:)    query = <<~GRAPHQL
    mutation createProjectTask($projectId: ID!, $title: String!, $description: String!, $statusId: ID, $priorityId: ID, $typeId: ID, $startDate: String) {
      createProjectTask(projectId: $projectId, title: $title, description: $description, statusId: $statusId, priorityId: $priorityId, typeId: $typeId, startDate: $startDate) {
          id
          title
        }
      }
    GRAPHQL

    variables = {
      projectId: project_id,
      title: title,
      description: description,
      statusId: status_id,
      priorityId: priority_id,
      typeId: type_id,
      startDate: start_date
    }

    execute_query(query, variables)
  end

  def create_project_comment(task_id:, content:)
    query = <<~GRAPHQL
      mutation createProjectComment($taskId: ID!, $content: String!) {
        createProjectComment(taskId: $taskId, content: $content) {
          id
          # Other fields you may want to retrieve after creating the comment
        }
      }
    GRAPHQL
    variables = { taskId: task_id, content: content }
    execute_query(query, variables)
  end

  def update_project_task(id:, assigned_user_id:)
    query = <<~GRAPHQL
      mutation updateProjectTask($id: ID!, $assignedUserId: ID) {
        updateProjectTask(id: $id, assignedUserId: $assignedUserId) {
          id
          title
        }
      }
    GRAPHQL
    variables = { id: id, assignedUserId: assigned_user_id }
    execute_query(query, variables)
  end

  private

  def execute_query(query, variables = {})
    response = self.class.post("/", {
      body: { query: query, variables: variables }.to_json,
      headers: @headers
    })

    if response.success?
      if response.parsed_response["errors"]
        { "errors" => response.parsed_response["errors"].map { |e| e["message"] }.join(", ") }
      else
        response.parsed_response["data"]
      end
    else
      { "errors" => "HTTP Error: #{response.code}" }
    end

    rescue HTTParty::Error => e
      { "errors" => "HTTParty Error: #{e.message}" }
    rescue StandardError => e
      { "errors" => "Standard Error: #{e.message}" }
  end

  def pull_and_push_repository(import_url, http_url_to_repo, access_token)
    execute_command("git config --global http.postBuffer 524288000")

    tokenized_import_url = import_url.sub("https://", "https://#{access_token}@")

    Dir.mktmpdir do |dir|
      puts "Cloning into temporary directory: #{dir}"

      clone_command = "git clone #{tokenized_import_url} #{dir}"
      execute_command(clone_command)

      Dir.chdir(dir) do
        fetch_command = "git fetch --all"
        execute_command(fetch_command)

        branches = `git branch -r`.split("\n").map do |branch|
          branch.strip.sub("origin/", "")
        end

        branches.reject! { |branch| branch.include?("->") || branch == "HEAD" }

        add_remote_command = "git remote add codegiant #{http_url_to_repo}"
        execute_command(add_remote_command)

        branches.each do |branch|
          checkout_command = "git checkout #{branch}"
          execute_command(checkout_command)

          push_command = "git push codegiant #{branch}"
          execute_command(push_command)
        end
      end
    end
  end

  def execute_command(command)
    stdout, stderr, status = Open3.capture3(command)
    raise "Command failed: #{command}\nError: #{stderr}" unless status.success?

    stdout
  end
end
