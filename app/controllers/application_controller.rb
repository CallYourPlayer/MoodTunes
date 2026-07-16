class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception

  helper_method :current_user, :logged_in?

  private

  def current_user
    return @current_user if defined?(@current_user)

    @current_user = User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  # Guard for actions that require an authenticated user. Remembers where the
  # user was headed so we can send them back after a successful login.
  def authenticate_user!
    return if logged_in?

    session[:return_to] = request.fullpath if request.get?
    redirect_to login_path, alert: "Accedi per continuare."
  end
end
