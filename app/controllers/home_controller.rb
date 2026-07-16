class HomeController < ApplicationController
  before_action :authenticate_user!

  def index
    @moods  = Playlist::MOODS
    @genres = Playlist::GENRES
  end
end
