# spec/controllers/stories_controller_spec.rb
require "rails_helper"

RSpec.describe StoriesController, type: :controller do
  let(:playlist_id) { "playlist_123" }

  shared_context "logged in user" do
    let(:session_user) do
      {
        "id"           => "user123",
        "display_name" => "Test User",
        "email"        => "test@example.com"
      }
    end

    before do
      session[:spotify_user] = session_user
    end
  end

  describe "GET #show" do
    context "when user is not authenticated with Spotify" do
      it "redirects to home (via require_spotify_auth!)" do
        # No session[:spotify_user] set here
        get :show, params: { playlist_id: playlist_id }

        # Adjust this if your require_spotify_auth! redirects somewhere else
        expect(response).to have_http_status(:redirect)
        expect(response).to redirect_to(home_path).or redirect_to(root_path)
      end
    end

    context "when user is authenticated with Spotify" do
      include_context "logged in user"

      let(:mock_client) { instance_double(SpotifyClient) }

      let(:mock_tracks) do
        [
          OpenStruct.new(
            id:   "track_1",
            name: "Track One",
            artists: "Artist One"
          ),
          OpenStruct.new(
            id:   "track_2",
            name: "Track Two",
            artists: "Artist Two"
          )
        ]
      end

      before do
        # Ensure controller builds our double instead of real client
        allow(SpotifyClient).to receive(:new)
          .with(session: anything)
          .and_return(mock_client)

        allow(mock_client).to receive(:playlist_tracks)
          .with(playlist_id: playlist_id, limit: 100)
          .and_return(mock_tracks)
      end

      it "initializes SpotifyClient with the current session" do
        get :show, params: { playlist_id: playlist_id }

        expect(SpotifyClient).to have_received(:new)
            .with(session: hash_including("spotify_user" => session_user))
        end

      it "calls playlist_tracks with given playlist_id and limit 100" do
        get :show, params: { playlist_id: playlist_id }

        expect(mock_client).to have_received(:playlist_tracks)
          .with(playlist_id: playlist_id, limit: 100)
      end

      it "assigns @playlist_id and @tracks" do
        get :show, params: { playlist_id: playlist_id }

        expect(assigns(:playlist_id)).to eq(playlist_id)
        expect(assigns(:tracks)).to eq(mock_tracks)
      end

      it "renders the show template with 200 status" do
        get :show, params: { playlist_id: playlist_id }

        expect(response).to have_http_status(:ok)
        expect(response).to render_template(:show)
      end
    end
  end
end
