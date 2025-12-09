# spec/controllers/playlist_genres_controller_spec.rb
require "rails_helper"

RSpec.describe PlaylistGenresController, type: :controller do
  let(:session_user) do
    {
      "id"           => "user123",
      "display_name" => "Test User",
      "email"        => "test@example.com"
    }
  end

  let(:mock_client) { instance_double(SpotifyClient) }

  before do
    # Logged-in by default; override in specific contexts if needed
    session[:spotify_user] = session_user

    allow(SpotifyClient).to receive(:new)
      .with(session: anything)
      .and_return(mock_client)
  end

  describe "GET #index" do
    context "when user is logged in" do
      let(:playlists) do
        [
          { "id" => "pl1", "name" => "Playlist One" },
          { "id" => "pl2", "name" => "Playlist Two" }
        ]
      end

      before do
        allow(mock_client).to receive(:user_playlists)
          .with(limit: 50)
          .and_return(playlists)
      end

      it "assigns @playlists and renders :index" do
        get :index

        expect(response).to have_http_status(:ok)
        expect(assigns(:playlists)).to eq(playlists)
      end
    end

    context "when user is not logged in" do
      before do
        session.delete(:spotify_user)
      end

      it "redirects to home_path due to require_spotify_auth!" do
        get :index

        expect(response).to redirect_to(home_path)
      end
    end
  end

  describe "GET #show" do
    let(:playlist_id) { "playlist123" }

    context "with tracks that have genres" do
      let(:tracks_with_genres) do
        [
          { title: "Song 1", genres: %w[pop indie] },
          { title: "Song 2", genres: %w[pop] },
          { title: "Song 3", genres: [] }
        ]
      end

      let(:playlist_hash) do
        {
          "id" => playlist_id,
          "name" => "My Mix",
          "external_urls" => { "spotify" => "https://open.spotify.com/playlist/#{playlist_id}" }
        }
      end

      before do
        # playlist tracks + genres
        allow(mock_client).to receive(:playlist_tracks_with_genres)
          .with(playlist_id)
          .and_return(tracks_with_genres)

        # playlist metadata
        allow(mock_client).to receive(:get_playlist)
          .with(playlist_id)
          .and_return(playlist_hash)
      end

      it "builds @genre_breakdown, @top_genre, @playlist_url and @share_url" do
        get :show, params: { id: playlist_id }

        expect(response).to have_http_status(:ok)

        breakdown = assigns(:genre_breakdown)
        top_genre = assigns(:top_genre)

        # We had pop 3 times (2 in first track, 1 in second) and indie 1 time
        pop_entry   = breakdown.find { |g| g[:genre] == "pop" }
        indie_entry = breakdown.find { |g| g[:genre] == "indie" }

        expect(pop_entry).not_to be_nil
        expect(indie_entry).not_to be_nil
        expect(pop_entry[:count]).to eq(2) # two occurrences of "pop"
        expect(indie_entry[:count]).to eq(1)

        # pop should be top genre by count
        expect(top_genre).to eq("pop")

        # playlist URL comes from the playlist metadata
        expect(assigns(:playlist_url)).to eq("https://open.spotify.com/playlist/#{playlist_id}")

        # share_url is the show URL for this controller
        share_url = assigns(:share_url)
        expect(share_url).to include("/playlists/#{playlist_id}/genres")
      end
    end

    context "when playlist has no genres at all" do
      let(:tracks_with_genres) { [] }
      let(:playlist_hash) do
        {
          "id" => playlist_id,
          "name" => "Empty Mix",
          "external_urls" => { "spotify" => "https://open.spotify.com/playlist/#{playlist_id}" }
        }
      end

      before do
        allow(mock_client).to receive(:playlist_tracks_with_genres)
          .with(playlist_id)
          .and_return(tracks_with_genres)

        allow(mock_client).to receive(:get_playlist)
          .with(playlist_id)
          .and_return(playlist_hash)
      end

      it "assigns empty @genre_breakdown and nil @top_genre" do
        get :show, params: { id: playlist_id }

        expect(response).to have_http_status(:ok)
        expect(assigns(:genre_breakdown)).to eq([])
        expect(assigns(:top_genre)).to be_nil
      end
    end

    context "when user is not logged in" do
      before do
        session.delete(:spotify_user)
      end

      it "redirects to home_path due to require_spotify_auth!" do
        get :show, params: { id: playlist_id }

        expect(response).to redirect_to(home_path)
      end
    end
  end
end
