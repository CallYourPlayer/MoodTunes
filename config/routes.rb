Rails.application.routes.draw do
  root "home#index"

  # Live Deezer search proxy (avoids CORS, keeps the front-end simple).
  get "/deezer/search", to: "deezer_searches#index"

  resources :playlists, only: %i[create show], param: :slug do
    member do
      post   :regenerate
      post   :add_track
      delete :remove_track
      patch  :reorder
    end
  end
end
