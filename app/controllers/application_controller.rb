# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  helper_method :github_current_user

  def github_current_user
    @github_current_user ||= GithubAuthUser.find(session[:github_user_id]) if session[:github_user_id]
  end
end
