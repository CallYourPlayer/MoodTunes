class SessionsController < ApplicationController
  before_action :redirect_if_logged_in, only: %i[new create]

  # GET /login
  def new
  end

  # POST /login
  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase)

    if user&.authenticate(params[:password])
      destination = session[:return_to]
      reset_session # prevent session fixation
      session[:user_id] = user.id
      redirect_to(destination || root_path, notice: "Bentornato!")
    else
      flash.now[:alert] = "Email o password non corretti."
      render :new, status: :unprocessable_entity
    end
  end

  # DELETE /logout
  def destroy
    reset_session
    redirect_to root_path, notice: "Hai effettuato il logout."
  end

  private

  def redirect_if_logged_in
    redirect_to root_path if logged_in?
  end
end
