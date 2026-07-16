class PasswordsController < ApplicationController
  before_action :authenticate_user!

  # GET /password
  def edit
  end

  # PATCH /password
  def update
    unless current_user.authenticate(params[:current_password].to_s)
      flash.now[:alert] = "La password attuale non è corretta."
      return render :edit, status: :unprocessable_entity
    end

    if current_user.update(password_params)
      redirect_to root_path, notice: "Password aggiornata."
    else
      flash.now[:alert] = current_user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def password_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
