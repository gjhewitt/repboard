class SettingsController < ApplicationController
  before_action :authenticate_user!

  def edit
    @user = current_user
    3.times { @user.links.build } if @user.links.empty?
  end

  def update
    @user = current_user
    if @user.update(settings_params)
      redirect_to "/settings", notice: "Profile updated!"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def settings_params
    params.require(:user).permit(:avatar_url, :display_name, :bio, links_attributes: [ :id, :label, :url, :position, "_destroy" ])
  end
end
