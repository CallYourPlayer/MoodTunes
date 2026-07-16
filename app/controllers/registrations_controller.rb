class RegistrationsController < ApplicationController
  before_action :redirect_if_logged_in, only: %i[new create]

  # GET /signup
  def new
    @user = User.new
  end

  # POST /signup
  def create
    @user = User.new(user_params)

    if @user.save
      session[:user_id] = @user.id
      redirect_to after_auth_path, notice: "Benvenuto su MoodTunes!"
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation)
  end

  def redirect_if_logged_in
    redirect_to root_path if logged_in?
  end

  def after_auth_path
    session.delete(:return_to) || root_path
  end
end
