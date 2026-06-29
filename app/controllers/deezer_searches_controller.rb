class DeezerSearchesController < ApplicationController
  # GET /deezer/search?q=...
  # Server-side proxy so the browser never talks to Deezer directly.
  def index
    results = DeezerClient.new.search(params[:q].to_s, limit: 10)
    render json: { results: results }
  end
end
