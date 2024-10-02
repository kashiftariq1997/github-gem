class UpdateIssueUserJob < ApplicationJob
  queue_as :default

  def perform(project, jira_user_ids, code_giant_user_ids, token, work_space_id)
    graphql_service = GraphqlMutationService.new(token)
    id_to_graphql_id_mapping = GithubCodegiantUser.where(id: code_giant_user_ids).pluck(:id, :graphql_id).to_h

    unless project.code_giant_project_id.present?
      project_info = {
        workspace_id: work_space_id,
        project_type: "kanban",
        tracking_type: "time",
        prefix: project.prefix,
        title: project.name
      }

      project_response = graphql_service.create_project(**project_info)

      if project_response.dig("createProject", "id")
        created_project_id = project_response["createProject"]["id"]
        project.update(code_giant_project_id: created_project_id)
        # Create project statuses for the project using the statuses returned in the mutation response
        project_statuses = project_response.dig("createProject", "taskStatuses")
        if project_statuses.present?
          project_statuses&.each do |status|
            GithubProjectStatus.find_or_create_by(github_project_id: project.id, title: status["title"] ) do |project_status|
              project_status.status_id = status["id"]
            end
          end
        end
        project_types = project_response.dig("createProject", "taskTypes")

        if project_types.present?
          project_types&.each do |type|
            project_type = GithubProjectType.find_or_initialize_by(github_project_id: project.id, title: type["title"])
            project_type.type_id = type["id"]
            project_type.color = type["color"]
            project_type.complete_trigger = type["completeTrigger"]
            project_type.save!  # Save the record, updating if it already exists or creating a new one if it doesn't
          end
        end
        project_priorities = project_response.dig("createProject", "taskPriorities")

        if project_priorities.present?
            project_priorities&.each do |priority|
              project_priority = GithubProjectPriority.find_or_initialize_by(github_project_id: project.id, title: priority["title"])
              project_priority.priority_id = priority["id"]
              project_priority.save!  # Save the record, updating if it already exists or creating a new one if it doesn't
            end
          end
        elsif project_response["errors"]
          error_messages = if project_response["errors"].is_a?(Array)
                              project_response["errors"].map { |error| error["message"] }.join(", ")
                            else
                              project_response["errors"].to_s
                            end
          Rails.logger.error "Failed to create project in CodeGiant: #{error_messages}"
        return
      else
        Rails.logger.error "Failed to create project in CodeGiant for an unknown reason."
        return
      end
    else
      created_project_id = project.code_giant_project_id
    end

    field_mappings = project&.github_field_mapping
    GithubIssue.transaction do
      if jira_user_ids.present?
        jira_user_ids.zip(code_giant_user_ids).each do |jira_user_id, code_giant_user_id|
          username = GithubUser.find(jira_user_id).username
            issues =  project.github_repository.github_issues
                        .left_joins(:github_users)
                        .where(github_users: { username: username })
                        .or(
                          project.github_repository.github_issues
                          .left_joins(:github_users)
                          .where(github_users: { id: nil })
                        )
          issues.each do |issue|
            process_issue(issue, project, created_project_id, field_mappings, graphql_service, id_to_graphql_id_mapping, code_giant_user_id)
          end
        end
      else
        issues = project.issues.where(assignee_name: nil)

        issues.each do |issue|
          process_issue(issue, project, created_project_id, field_mappings, graphql_service, id_to_graphql_id_mapping, nil)
        end
      end
    end
    Rails.logger.info "Tasks created and user mapping updated successfully."
    repo = project&.github_repository
    repo&.destroy!
  end

  private

  def process_issue(issue, project, created_project_id, field_mappings, graphql_service, id_to_graphql_id_mapping, code_giant_user_id)

    status_mapping = {
      "OPEN" => "open",
      "CLOSED" => "complete"
    }

    mapped_status = status_mapping[issue&.state]
    status_id = project.github_project_statuses.find_by("LOWER(title) = ?", mapped_status)&.status_id if mapped_status

    type_mapping = {
      "Story" => "story",
      "Bug" => "bug",
      "Sub-task" => "subtask",
      "New Feature" => "feature"
    }

    code_giant_user_id_to_use = issue.github_users.nil? ? nil : code_giant_user_id

    if issue.codegiant_task_id.blank?
      task_info = {
        project_id: created_project_id,
        title: issue.public_send(field_mappings&.mapping&.fetch('Title', :title) || :title),
        start_date: issue.public_send(field_mappings&.mapping&.fetch('Start Datde', :created_at) || :created_at),
        status_id: status_id
      }

      description_fields = field_mappings&.mapping&.fetch('Description', [:description])
      description_values = description_fields&.map do |field|
        value = issue.public_send(field)
        "#{field}: #{value}" unless value.blank?
      end.compact&.join("\n")

      task_info[:description] = description_values || ''

      task_info[:priority_id] = GithubProjectPriority.find_by(title: "minor").priority_id
      task_info[:type_id] = GithubProjectType.find_by(title: 'bug').type_id
      task_response = graphql_service.create_project_task(**task_info)


      if task_response["createProjectTask"] && task_response["createProjectTask"]["id"]
        created_task_id = task_response["createProjectTask"]["id"]
        issue.update(codegiant_task_id: created_task_id)
        create_comments_for_issue(issue, graphql_service, created_task_id)
      else
        Rails.logger.error "Failed to create task for issue #{issue.id} in CodeGiant"
      end
    end

    if issue.codegiant_task_id.present? && !code_giant_user_id_to_use.nil?
      code_giant_user_graphql_id = id_to_graphql_id_mapping[code_giant_user_id_to_use.to_i]

      task_update_info = {
        id: issue.codegiant_task_id,
        assigned_user_id: code_giant_user_graphql_id
      }
      update_response = graphql_service.update_project_task(**task_update_info)
      unless update_response.dig("updateProjectTask", "id")
        Rails.logger.error "Failed to update task #{issue.codegiant_task_id} in CodeGiant"
      end
    end
  end

  def create_comments_for_issue(issue, graphql_service, created_task_id)
    issue&.github_comments.each do |comment|
      comment_info = {
        task_id: created_task_id,
        content: comment&.body
      }
      comment_response = graphql_service.create_project_comment(**comment_info)

      if comment_response["createProjectComment"] && comment_response["createProjectComment"]["id"]
        Rails.logger.info "Comment created successfully for task #{created_task_id}"
      else
        Rails.logger.error "Failed to create comment for task #{created_task_id}"
      end
    end
  end
end
