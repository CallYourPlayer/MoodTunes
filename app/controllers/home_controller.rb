class HomeController < ApplicationController
  def index
    @moods  = Playlist::MOODS
    @genres = Playlist::GENRES
  end
end
