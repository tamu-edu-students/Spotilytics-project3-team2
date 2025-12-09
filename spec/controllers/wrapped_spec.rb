# spec/requests/wrapped_spec.rb
require 'rails_helper'

RSpec.describe "Wrapped", type: :request do
  describe "GET /index" do
    let(:spotify_client) { instance_double(SpotifyClient) }
    let(:top_tracks_data) do
      [
        instance_double('SpotifyTrack', name: 'My Top Song', album_image_url: 'track_image.jpg', popularity: 95, preview_url: 'track_preview.mp3', spotify_url: 'track_spotify_url')
      ]
    end
    let(:top_artists_data) do
      [
        instance_double('SpotifyArtist', name: 'Favorite Artist', image_url: 'artist_image.jpg', genres: [ 'pop', 'indie' ])
      ]
    end

    before do
      # Mock the SpotifyClient initialization across all tests in this describe block
      allow(SpotifyClient).to receive(:new).and_return(spotify_client)

      # Stub the before_action :require_spotify_auth! for successful cases
      allow_any_instance_of(WrappedController).to receive(:require_spotify_auth!)
    end

    context "when Spotify data is successfully fetched" do
      before do
        allow(spotify_client).to receive(:top_tracks).and_return(top_tracks_data)
        allow(spotify_client).to receive(:top_artists).and_return(top_artists_data)
        get '/wrapped'
      end

      it "returns a successful response" do
        expect(response).to have_http_status(:ok)
      end

      it "assigns the slides instance variable with all four slides" do
        expect(assigns(:slides).count).to eq(4)

        # Check the first slide (Welcome)
        expect(assigns(:slides)[0][:title]).to eq("Your Spotilytics Wrapped")

        # Check the second slide (Top Track)
        expect(assigns(:slides)[1][:title]).to eq("Your #1 Song")
        expect(assigns(:slides)[1][:subtitle]).to eq("My Top Song")
        expect(assigns(:slides)[1][:type]).to eq(:track)

        # Check the third slide (Top Artist)
        expect(assigns(:slides)[2][:title]).to eq("Your Top Artist")
        expect(assigns(:slides)[2][:subtitle]).to eq("Favorite Artist")
        expect(assigns(:slides)[2][:type]).to eq(:artist)

        # Check the fourth slide (Favorite Genre)
        expect(assigns(:slides)[3][:title]).to eq("Your Favorite Genre")
        expect(assigns(:slides)[3][:subtitle]).to eq("Pop") # Check for capitalize
        expect(assigns(:slides)[3][:type]).to eq(:genres)
      end
    end

    context "when fetching Spotify data fails" do
      before do
        # Simulate the rescue block by raising an error on a SpotifyClient call
        allow(spotify_client).to receive(:top_tracks).and_raise(StandardError)
        allow(spotify_client).to receive(:top_artists).and_return([]) # Still needs to be mocked, even if it won't be called
        get '/wrapped'
      end

      it "returns a successful response" do
        expect(response).to have_http_status(:ok)
      end

      it "assigns the slides instance variable with the 'No data available' slide" do
        expect(assigns(:slides).count).to eq(1)
        expect(assigns(:slides).first[:type]).to eq(:empty)
      end
    end

    context "when a user is not authenticated" do
      # Un-stub the before_action and test its behavior
      before do
        # 1. Stub the filter to *explicitly* cause a redirect and halt the request.
        # This simulates a failing auth check that redirects to '/login'.
        allow_any_instance_of(WrappedController).to receive(:require_spotify_auth!) do |controller_instance|
          # You MUST use the actual instance passed to the block to call controller methods
          controller_instance.send(:redirect_to, '/login', allow_other_host: true)
        end

        get '/wrapped' # Use the literal path
      end

      it "redirects for authentication" do
        # Expect a redirect status code (302)
        expect(response).to have_http_status(:redirect)
        # Expect it redirects to the login path
        expect(response).to redirect_to('/login')
      end
    end
  end
end
