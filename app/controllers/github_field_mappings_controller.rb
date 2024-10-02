class GithubFieldMappingsController < ApplicationController
  def create
    # Permit github_project_id from github_field_mapping
    github_project_id = params.require(:github_field_mapping).permit(:github_project_id)

    # Permit the field mapping parameters separately from field_mapping
    field_mapping_params = params.require(:field_mapping).permit(github_field: [], codegiant_field: [])

    # Initialize a new hash for storing the mappings
    mapping_hash = {}

    # Iterate over the parameters and populate the mapping hash
    field_mapping_params[:codegiant_field].zip(field_mapping_params[:github_field]).each do |codegiant_field, github_field|
      if codegiant_field == 'Description'
        # If the field is 'Description', append the GitHub field to an array
        mapping_hash[codegiant_field] ||= []
        mapping_hash[codegiant_field] << github_field
      else
        # For other fields, just assign the value
        mapping_hash[codegiant_field] = github_field
      end
    end

    # Find the GitHub project by the permitted github_project_id
    github_project = GithubProject.find(github_project_id[:github_project_id])

    # Check if the GitHub project already has a field mapping
    @field_mapping = github_project.github_field_mapping || GithubFieldMapping.new(github_project: github_project)

    # Assign the mapping hash to the field mapping
    @field_mapping.mapping = mapping_hash

    if @field_mapping.save
      # Redirect to the next page after successful save
      redirect_to codegiant_users_page_path(github_project), notice: 'Field mapping was successfully saved.'
    else
      # Render the form again if the save fails
      render :new
    end
  end
end
