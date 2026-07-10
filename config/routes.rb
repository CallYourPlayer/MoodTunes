Rails.application.routes.draw do
  root "home#index"

  # Live YouTube search proxy (keeps the API key server-side).
  get "/youtube/search", to: "youtube_searches#index"

  resources :playlists, only: %i[index create show destroy], param: :slug do
    member do
      post   :regenerate
      post   :add_track
      delete :remove_track
      patch  :reorder
    end
  end
end
