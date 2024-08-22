class GithubSessionsController < ApplicationController
  skip_before_action :verify_authenticity_token, only: :create

  def create
    user = GithubAuthUser.from_omniauth(request.env['omniauth.auth'])
    session[:github_user_id] = user.id
    redirect_to root_path, notice: "Signed in!"
  end

  def destroy
    session[:github_user_id] = nil
    redirect_to root_path, notice: "Signed out!"
  end

  def failure
    redirect_to root_path, alert: "Authentication failed, please try again."
  end
end
