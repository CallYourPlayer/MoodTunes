class YoutubeSearchesController < ApplicationController
  # GET /youtube/search?q=...
  # Server-side proxy so the browser never sees the YouTube API key.
  def index
    results = YoutubeClient.new.search(params[:q].to_s, limit: 10)
    render json: { results: results }
  end
end
