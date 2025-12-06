Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
  get "/dashboard", to: "pages#dashboard", as: :dashboard
  get "/top-artists", to: "pages#top_artists", as: :top_artists
  get "/home", to: "pages#home", as: :home
  get "/view-profile", to: "pages#view_profile", as: :view_profile
  get "/clear", to: "pages#clear", as: :clear
  get "/listening-patterns", to: "listening_patterns#hourly", as: :listening_patterns
  get "/listening-monthly", to: "listening_patterns#monthly", as: :listening_monthly
  get "/mood-explorer", to: "pages#mood_explorer"
  get "/mood-analysis/:id", to: "pages#mood_analysis", as: :mood_analysis
  get "/listening-heatmap", to: "listening_patterns#calendar", as: :listening_heatmap
  get "/playlists/:id/energy", to: "pages#playlist_energy", as: :playlist_energy
  resources :playlists, only: [] do
    collection do
      get :compare_form
      get :compare
    end
  end
  get "/personality", to: "personality#show", as: :personality
  root "pages#home"

  # Callback from Spotify
  match "/auth/spotify/callback", to: "sessions#create", via: %i[get post]
  get    "/auth/failure",         to: "sessions#failure"
  get    "/login",                to: redirect("/auth/spotify"), as: :login
  delete "/logout", to: "sessions#destroy", as: :logout

  resources :artist_follows, only: [ :create, :destroy ], param: :spotify_id

  # GET /top_tracks
  get "/top_tracks", to: "top_tracks#index", as: :top_tracks
  post "/create_playlist", to: "playlists#create", as: :create_playlist

  # Get Recommendations
  get  "recommendations",        to: "recommendations#recommendations",   as: :recommendations
end
