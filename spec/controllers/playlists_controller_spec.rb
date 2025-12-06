require "rails_helper"

RSpec.describe PlaylistsController, type: :controller do
  let(:session_user) do
    { "id" => "spotify-user-1", "display_name" => "Test User" }
  end

  before { session[:spotify_user] = session_user }

  describe "GET #compare" do
    let(:mock_client) { instance_double(SpotifyClient) }
    let(:mock_service) { instance_double(PlaylistComparisonService) }
    let(:mock_result) do
      PlaylistComparisonService::CompatibilityResult.new(
        compatibility: 90,
        overlap_count: 2,
        overlap_pct: 50.0,
        common_tracks: [],
        only_in_a: [],
        only_in_b: [],
        vector_a: [ 1, 0, 0, 0, 0 ],
        vector_b: [ 1, 0, 0, 0, 0 ],
        valid_a: 5,
        valid_b: 5,
        flags: []
      )
    end

    before do
      allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock_client)
      allow(PlaylistComparisonService).to receive(:new).with(client: mock_client).and_return(mock_service)
      allow(mock_service).to receive(:compare).and_return(mock_result)
    end

    it "assigns comparison data" do
      get :compare, params: { source_id: "plA", target_id: "plB" }

      expect(response).to have_http_status(:ok)
      expect(assigns(:compatibility_score)).to eq(90)
      expect(assigns(:overlap_count)).to eq(2)
      expect(assigns(:overlap_pct)).to eq(50.0)
      expect(assigns(:vector_a)).to eq([ 1, 0, 0, 0, 0 ])
      expect(assigns(:explanations)).to be_present
    end

    it "redirects when ids missing" do
      get :compare, params: { source_id: "", target_id: "" }

      expect(response).to redirect_to(compare_form_playlists_path)
      expect(flash[:alert]).to eq("Please enter both playlist IDs.")
    end
  end

  describe "#normalize_playlist_id" do
    it "extracts id from spotify url" do
      expect(controller.send(:normalize_playlist_id, "https://open.spotify.com/playlist/abc123?si=xyz")).to eq("abc123")
    end

    it "returns stripped id when raw" do
      expect(controller.send(:normalize_playlist_id, "  raw123  ")).to eq("raw123")
    end
  end

  describe "POST #create" do
    let(:mock_client) { instance_double(SpotifyClient) }

    before do
      allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock_client)
    end

    it "redirects on invalid range" do
      post :create, params: { time_range: "bad" }
      expect(response).to redirect_to(top_tracks_path)
      expect(flash[:alert]).to eq("Invalid time range.")
    end

    it "redirects when no tracks returned" do
      allow(mock_client).to receive(:top_tracks).and_return([])
      post :create, params: { time_range: "short_term" }
      expect(response).to redirect_to(top_tracks_path)
      expect(flash[:alert]).to include("No tracks available")
    end

    it "creates playlist and adds tracks" do
      tracks = [ OpenStruct.new(id: "t1"), OpenStruct.new(id: "t2") ]
      allow(mock_client).to receive(:top_tracks).and_return(tracks)
      allow(mock_client).to receive(:create_playlist_for).and_return("pl123")
      allow(mock_client).to receive(:add_tracks_to_playlist).and_return(true)

      post :create, params: { time_range: "short_term" }

      expect(response).to redirect_to(top_tracks_path)
      expect(flash[:notice]).to include("Playlist created on Spotify")
    end
  end
end
