# features/step_definitions/pages_top_tracks_steps.rb
require 'ostruct'

# Test-only controller to call PagesController#top_tracks and render a simple count.
unless defined?(CucumberPagesTopTracksController)
  class CucumberPagesTopTracksController < PagesController
    def index
      self.top_tracks  # sets @top_tracks OR redirects/rescues
      render plain: "COUNT=#{@top_tracks.size}" if performed? == false
    end
  end
end

Given("a test endpoint that proxies to pages#top_tracks") do
  Rails.application.routes.draw do
    get "/cuke_pages_top_tracks", to: "cucumber_pages_top_tracks#index", as: :cuke_pages_top_tracks
    # keep your existing routes so other scenarios still run
    get '/dashboard',    to: 'pages#dashboard',    as: :dashboard
    get '/top-artists',  to: 'pages#top_artists',  as: :top_artists
    get '/home',         to: 'pages#home',         as: :home
    get '/view-profile', to: 'pages#view_profile', as: :view_profile
    get '/clear',        to: 'pages#clear',        as: :clear
    get '/listening-patterns', to: 'listening_patterns#hourly', as: :listening_patterns
    get '/listening-monthly',  to: 'listening_patterns#monthly', as: :listening_monthly
    get '/listening-heatmap',  to: 'listening_patterns#calendar', as: :listening_heatmap
    get '/personality', to: 'personality#show', as: :personality
    resources :playlists, only: [] do
      collection do
        get :compare_form
        get :compare
      end
    end
    root 'pages#home'
    match '/auth/spotify/callback', to: 'sessions#create', via: %i[get post]
    get '/auth/failure', to: "sessions#failure"
    get '/login',        to: redirect("/auth/spotify"), as: :login
    delete '/logout',    to: 'sessions#destroy', as: :logout
    get "/top_tracks",   to: "top_tracks#index", as: :top_tracks
    get 'recommendations', to: 'recommendations#recommendations', as: :recommendations
  end
end

After { Rails.application.reload_routes! }

# Stubs
Given('Spotify returns N top tracks {string} for any time range') do |n_str|
  n = n_str.to_i
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock)
  allow(mock).to receive(:top_tracks) do |args|
    Array.new(n) { |i| OpenStruct.new(id: "t#{i+1}") }
  end
end

Given('Spotify top tracks raises Unauthorized (pages)') do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock)
  allow(mock).to receive(:top_tracks).and_raise(SpotifyClient::UnauthorizedError.new('expired'))
end

Given('Spotify top tracks raises a generic error (pages)') do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock)
  allow(mock).to receive(:top_tracks).and_raise(SpotifyClient::Error.new('rate limited'))
end

When('I visit the pages top tracks test endpoint with limit {string}') do |val|
  visit Rails.application.routes.url_helpers.cuke_pages_top_tracks_path(limit: val)
end

Then('I should see "COUNT={int}"') do |n|
  expect(page).to have_content("COUNT=#{n}")
end

Given("Spotify top tracks raises Unauthorized (pages)") do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock)
  allow(mock).to receive(:top_tracks).and_raise(SpotifyClient::UnauthorizedError.new("expired"))
end

Given("Spotify top tracks raises a generic error (pages)") do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock)
  allow(mock).to receive(:top_tracks).and_raise(SpotifyClient::Error.new("boom"))
end

# Disambiguate the COUNT assertion so it won't conflict with the generic "I should see {string}"
Then(/^I should see COUNT=(\d+)$/) do |n|
  expect(page).to have_content("COUNT=#{n}")
end

Given('Spotify top tracks raises Unauthorized (pages)') do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock)
  allow(mock).to receive(:top_tracks).and_raise(SpotifyClient::UnauthorizedError.new('expired'))
end

Given('Spotify top tracks raises a generic error (pages)') do
  mock = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock)
  allow(mock).to receive(:top_tracks).and_raise(SpotifyClient::Error.new('rate limited'))
end
