Rails.application.routes.draw do
  root "home#index"

  # Authentication
  get    "/signup", to: "registrations#new"
  post   "/signup", to: "registrations#create"
  get    "/login",  to: "sessions#new"
  post   "/login",  to: "sessions#create"
  delete "/logout", to: "sessions#destroy"

  # Change password (logged-in user)
  get    "/password", to: "passwords#edit"
  patch  "/password", to: "passwords#update"

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
