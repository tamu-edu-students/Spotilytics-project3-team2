# spec/controllers/pages_controller_dashboard_top_tracks_spec.rb
require "rails_helper"
require "set"

RSpec.describe PagesController, type: :controller do
  shared_context "logged in user" do
    let(:session_user) do
      {
        "id"           => "user_123",
        "display_name" => "Test Listener",
        "email"        => "listener@example.com",
        "image"        => "http://example.com/user.jpg"
      }
    end

    before { session[:spotify_user] = session_user }
  end

  describe "GET #dashboard (Top Tracks preview section)" do
    include_context "logged in user"

    context "when SpotifyClient returns top tracks successfully" do
      render_views

      let(:mock_tracks) do
        [
          OpenStruct.new(
            name: "Track One",
            artists: "Artist One",
            album_name: "Album One",
            album_image_url: "http://img/one.jpg",
            popularity: 90
          ),
          OpenStruct.new(
            name: "Track Two",
            artists: "Artist Two",
            album_name: "Album Two",
            album_image_url: "http://img/two.jpg",
            popularity: 80
          )
        ]
      end

      before do
        mock_client = instance_double(SpotifyClient)

        allow(SpotifyClient).to receive(:new)
          .with(session: anything)
          .and_return(mock_client)

        # dashboard builds top tracks preview with 10/long_term
        allow(mock_client).to receive(:top_tracks)
          .with(limit: 10, time_range: "long_term")
          .and_return(mock_tracks)

        # dashboard also fetches top artists; stub it to something harmless
        allow(mock_client).to receive(:top_artists).and_return([])

        # dashboard also fetches followed; stub it to something harmless
        allow(mock_client).to receive(:followed_artists).and_return([])

        # dashboard also fetches new releases; stub it to something harmless
        allow(mock_client).to receive(:new_releases).and_return([])
      end

      it "assigns top tracks and primary track for the preview card" do
        get :dashboard

        expect(assigns(:top_tracks)).to eq(mock_tracks)
        expect(assigns(:primary_track)).to eq(mock_tracks.first)
        expect(response).to have_http_status(:ok)

        # light smoke check against the rendered HTML
        expect(response.body).to include("Track One")
        expect(response.body).to include("Artist One")
      end
    end

    context "when SpotifyClient raises UnauthorizedError while fetching top tracks" do
      before do
        mock_client = instance_double(SpotifyClient)

        allow(SpotifyClient).to receive(:new)
          .with(session: anything)
          .and_return(mock_client)

        allow(mock_client).to receive(:top_tracks)
          .and_raise(SpotifyClient::UnauthorizedError.new("expired token"))

        # stub other calls invoked by dashboard to also fail the same way
        allow(mock_client).to receive(:top_artists)
          .and_raise(SpotifyClient::UnauthorizedError.new("expired token"))
      end

      it "redirects to home with the re-auth alert" do
        get :dashboard

        expect(response).to redirect_to(home_path)
        expect(flash[:alert]).to eq(
          "You must log in with spotify to access the dashboard."
        )
      end
    end

    context "when SpotifyClient raises a generic Error while fetching top tracks" do
      render_views

      before do
        mock_client = instance_double(SpotifyClient)

        allow(SpotifyClient).to receive(:new)
          .with(session: anything)
          .and_return(mock_client)

        allow(mock_client).to receive(:top_tracks)
          .and_raise(SpotifyClient::Error.new("rate limited"))

        allow(mock_client).to receive(:top_artists)
          .and_raise(SpotifyClient::Error.new("rate limited"))
      end

      it "renders 200, sets flash.now alert, and assigns empty preview values" do
        get :dashboard

        expect(assigns(:top_tracks)).to eq([])
        expect(assigns(:primary_track)).to be_nil

        expect(flash.now[:alert]).to eq(
          "We were unable to load your Spotify data right now. Please try again later."
        )
        expect(response).to have_http_status(:ok)

        # optional: smoke check that dashboard content rendered
        expect(response.body).to include("Top Tracks").or include("Your Top")
      end
    end
  end

  describe "GET #dashboard (Top Artists + genre chart)" do
    include_context "logged in user"
    render_views

    before { session[:spotify_user] = session_user }

    let(:mock_client) { instance_double(SpotifyClient) }

    before do
      allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock_client)
      allow(mock_client).to receive(:top_tracks).with(limit: 10, time_range: "long_term").and_return([])
      allow(mock_client).to receive(:followed_artists).and_return([])
      allow(mock_client).to receive(:new_releases).and_return([])
    end

    context "when SpotifyClient returns artists with genres" do
      render_views

      let(:mock_artists) do
        10.times.map do |i|
          OpenStruct.new(
            id: "a#{i+1}",
            name: "Artist #{i+1}",
            rank: i + 1,
            image_url: "https://example.com/a#{i+1}.jpg",
            genres: [ "genre_#{i+1}" ],
            popularity: 60,
            playcount: 50
          )
        end
      end

      before do
        session[:spotify_user] = session_user
        mock_client = instance_double(SpotifyClient)
        allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock_client)
        allow(mock_client).to receive(:top_tracks).with(limit: 10, time_range: "long_term").and_return([])
        allow(mock_client).to receive(:top_artists).and_return(mock_artists)
        allow(mock_client).to receive(:followed_artists).and_return([])
        allow(mock_client).to receive(:new_releases).and_return([])
      end

      it "assigns @genre_chart with an 'Other' bucket" do
        get :dashboard

        chart = assigns(:genre_chart)
        expect(chart).to be_present

        labels = chart[:labels]
        data   = chart[:datasets].first[:data]

        expect(labels.size).to eq(data.size)
        expect(labels.last).to eq("Other")

        expect(data.last).to eq(2)
      end
    end

    context "when artists return with NO genres" do
      before do
        artists = [ OpenStruct.new(name: "A1", genres: []), OpenStruct.new(name: "A2", genres: nil) ]
        allow(mock_client).to receive(:top_artists).and_return(artists)
      end

      it "sets @genre_chart to nil (no slices to draw)" do
        get :dashboard
        expect(assigns(:genre_chart)).to be_nil
        expect(response).to have_http_status(:ok)
      end
    end

    context "when top_artists raises UnauthorizedError" do
      before do
        allow(mock_client).to receive(:top_artists)
          .and_raise(SpotifyClient::UnauthorizedError.new("expired"))
        allow(mock_client).to receive(:top_tracks)
          .and_raise(SpotifyClient::UnauthorizedError.new("expired"))
      end

      it "redirects to home with the re-auth alert" do
        get :dashboard
        expect(response).to redirect_to(home_path)
        expect(flash[:alert]).to eq('You must log in with spotify to access the dashboard.')
      end
    end

    context "when top_artists raises generic Error" do
      before do
        allow(mock_client).to receive(:top_artists)
          .and_raise(SpotifyClient::Error.new("rate limited"))
        allow(mock_client).to receive(:top_tracks)
          .and_raise(SpotifyClient::Error.new("rate limited"))
      end

      it "renders 200 with flash.now and assigns empty artists + nil primary + nil chart" do
        get :dashboard
        expect(assigns(:top_artists)).to eq([])
        expect(assigns(:primary_artist)).to be_nil
        expect(assigns(:genre_chart)).to be_nil
        expect(flash.now[:alert]).to eq('We were unable to load your Spotify data right now. Please try again later.')
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "GET #top_artists" do
    include_context "logged in user"

    let(:mock_client) { instance_double(SpotifyClient) }

    before do
      allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock_client)
    end

    context "success with custom limits" do
      render_views

      let(:artists_stub) do
        [
          OpenStruct.new(
            id: "a1", name: "Artist 1", rank: 1,
            image_url: "http://img/a1.jpg",
            genres: [ "pop" ], popularity: 65, playcount: 42
          )
        ]
      end

      it "assigns @top_artists_by_range, @limits, and @time_ranges" do
        expect(mock_client).to receive(:top_artists).with(limit: 25, time_range: "short_term").and_return(artists_stub)
        expect(mock_client).to receive(:top_artists).with(limit: 50, time_range: "medium_term").and_return(artists_stub)
        expect(mock_client).to receive(:top_artists).with(limit: 10, time_range: "long_term").and_return(artists_stub)
        expect(mock_client).to receive(:followed_artist_ids).with([ "a1" ]).and_return(Set.new([ "a1" ]))

        get :top_artists, params: { limit_short_term: "25", limit_medium_term: "50", limit_long_term: "abc" }

        expect(assigns(:limits)).to eq({ "short_term" => 25, "medium_term" => 50, "long_term" => 10 })
        expect(assigns(:top_artists_by_range)["short_term"]).to eq(artists_stub)
        expect(assigns(:top_artists_by_range)["medium_term"]).to eq(artists_stub)
        expect(assigns(:top_artists_by_range)["long_term"]).to eq(artists_stub)
        expect(assigns(:followed_artist_ids)).to eq(Set.new([ "a1" ]))
        expect(assigns(:time_ranges)).to eq(PagesController::TOP_ARTIST_TIME_RANGES)
        expect(response).to have_http_status(:ok)
      end
    end

    context "when SpotifyClient raises UnauthorizedError" do
      it "redirects to home with the re-auth alert" do
        allow(mock_client).to receive(:top_artists).and_raise(SpotifyClient::UnauthorizedError.new("expired"))

        get :top_artists

        expect(response).to redirect_to(home_path)
        expect(flash[:alert]).to eq("You must log in with spotify to view your top artists.")
      end
    end

    context "when SpotifyClient raises a generic Error" do
      render_views

      it "renders 200, sets flash.now, and assigns empty hash + default limits + time_ranges" do
        allow(mock_client).to receive(:top_artists).and_raise(SpotifyClient::Error.new("rate limited"))

        get :top_artists

        expect(response).to have_http_status(:ok)
        expect(flash.now[:alert]).to eq("We were unable to load your top artists from Spotify. Please try again later.")
        expect(assigns(:top_artists_by_range)).to eq({
          "long_term"   => [],
          "medium_term" => [],
          "short_term"  => []
        })
        expect(assigns(:limits)).to eq({
          "long_term"   => 10,
          "medium_term" => 10,
          "short_term"  => 10
        })
        expect(assigns(:time_ranges)).to eq(PagesController::TOP_ARTIST_TIME_RANGES)
      end
    end

    context "when SpotifyClient::Error with insufficient scope occurs" do
      let(:artists_stub) do
        [
          OpenStruct.new(
            id: "a1", name: "Artist 1", rank: 1,
            image_url: "http://img/a1.jpg",
            genres: [ "pop" ], popularity: 65, playcount: 42
          )
        ]
      end

      before do
        # Force the controller to think this is an insufficient scope error
        allow(controller).to receive(:insufficient_scope?).and_return(true)
        allow(mock_client).to receive(:followed_artist_ids).and_raise(SpotifyClient::Error.new("insufficient client scope"))
        allow(mock_client).to receive(:top_artists).with(limit: 10, time_range: "long_term").and_return(artists_stub)
        allow(mock_client).to receive(:top_artists).with(limit: 10, time_range: "medium_term").and_return(artists_stub)
        allow(mock_client).to receive(:top_artists).with(limit: 10, time_range: "short_term").and_return(artists_stub)
      end

      it "resets the Spotify session and redirects to login with an alert" do
        get :top_artists

        # Expect redirect
        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to match(/Spotify now needs permission/)

        # Expect tokens cleared
        expect(session[:spotify_token]).to be_nil
        expect(session[:spotify_refresh_token]).to be_nil
        expect(session[:spotify_expires_at]).to be_nil
      end
    end
  end

  describe "GET #top_tracks (PagesController)" do
  include_context "logged in user"

  routes { ActionDispatch::Routing::RouteSet.new }
  before do
    routes.draw do
      get "top_tracks" => "pages#top_tracks"
      get "track_journey" => "pages#track_journey"
      get "home"       => "pages#home"
    end
  end

  let(:mock_client) { instance_double(SpotifyClient) }
  before { allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock_client) }

  context "when Spotify raises UnauthorizedError" do
    it "redirects to home with the re-auth alert" do
      allow(mock_client).to receive(:top_tracks)
        .and_raise(SpotifyClient::UnauthorizedError.new("expired"))

      get :top_tracks, params: { limit: "25" }

      expect(response).to redirect_to(home_path)
      expect(flash[:alert]).to eq("You must log in with spotify to view your top tracks.")
      end
    end
  end

  describe 'GET #top_tracks' do
    before do
      routes.draw do
        get '/top_tracks' => 'pages#top_tracks'
      end

      allow(controller).to receive(:default_render).and_return(nil)
    end

    after { Rails.application.reload_routes! }

    it 'generic error branch logs, flashes and assigns empty @top_tracks' do
      session[:spotify_user] = { 'display_name' => 'Spec' }

      mock = instance_double(SpotifyClient)
      allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock)
      allow(mock).to receive(:top_tracks)
        .with(limit: 10, time_range: 'long_term')
        .and_raise(SpotifyClient::Error.new('rate limited'))

      expect(Rails.logger).to receive(:warn).with(/Failed to fetch Spotify top tracks: rate limited/)

      get :top_tracks, params: { limit: '10' }

      expect(flash.now[:alert]).to eq('We were unable to load your top tracks from Spotify. Please try again later.')
      expect(assigns(:top_tracks)).to eq([])
    end
  end

  describe "GET #view_profile" do
    include_context "logged in user"

    context "when SpotifyClient returns profile successfully" do
      render_views

      let(:mock_profile) do
        OpenStruct.new(
          id: "user123",
          display_name: "Test Listener",
          image_url: "http://example.com/user.jpg",
          followers: 42,
          spotify_url: "https://open.spotify.com/user/user123"
        )
      end

      before do
        mock_client = instance_double(SpotifyClient)
        allow(SpotifyClient).to receive(:new)
          .with(session: anything)
          .and_return(mock_client)
        allow(mock_client).to receive(:profile).and_return(mock_profile)
      end

      it "assigns @profile and renders the view" do
        get :view_profile

        expect(assigns(:profile)).to eq(mock_profile)
        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Test Listener")
      end
    end

    context "when SpotifyClient raises UnauthorizedError when fetching profile" do
      before do
        mock_client = instance_double(SpotifyClient)
        allow(SpotifyClient).to receive(:new)
          .with(session: anything)
          .and_return(mock_client)
        allow(mock_client).to receive(:profile)
          .and_raise(SpotifyClient::UnauthorizedError.new("expired token"))
      end

      it "redirects to home with the re-auth alert" do
        get :view_profile
        expect(response).to redirect_to(home_path)
        expect(flash[:alert]).to eq("You must log in with spotify to view your profile.")
      end
    end

    context "when SpotifyClient raises a generic Error" do
      before do
        mock_client = instance_double(SpotifyClient)
        allow(SpotifyClient).to receive(:new)
          .with(session: anything)
          .and_return(mock_client)
        allow(mock_client).to receive(:profile)
          .and_raise(SpotifyClient::Error.new("rate limited"))
      end

      it "renders 200, sets flash.now alert, and assigns @profile to nil" do
        get :view_profile
        expect(assigns(:profile)).to be_nil
        expect(flash.now[:alert]).to eq("We were unable to load your Spotify data right now. Please try again later.")
        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "Refresh Data" do
    include_context "logged in user"

    context "when SpotifyClient successfully clears cache" do
      before do
        mock_client = instance_double(SpotifyClient)
        allow(SpotifyClient).to receive(:new)
          .with(session: anything)
          .and_return(mock_client)
        allow(mock_client).to receive(:clear_user_cache).and_return([])
      end

      it "redirects to home path" do
        get :clear

        expect(response).to redirect_to(home_path)
      end

      it "flashes the correct notice" do
        get :clear

        expect(flash[:notice]).to eq('Data refreshed successfully')
      end
    end

    context "when SpotifyClient raises UnauthorizedError when refreshing data" do
      before do
        mock_client = instance_double(SpotifyClient)
        allow(SpotifyClient).to receive(:new)
          .with(session: anything)
          .and_return(mock_client)
        allow(mock_client).to receive(:clear_user_cache)
        .and_raise(SpotifyClient::UnauthorizedError.new("expired token"))
      end

      it "redirects to home with re-auth alert" do
        get :clear

        expect(response).to redirect_to(home_path)
        expect(flash[:alert]).to eq("You must log in with spotify to refresh your data.")
      end
    end
  end

  describe "GET #track_journey" do
    routes { ActionDispatch::Routing::RouteSet.new }

    before do
      routes.draw do
        get "track_journey" => "pages#track_journey"
        get "home" => "pages#home"
      end
      allow(controller).to receive(:default_render).and_return(nil)
    end

    context "when user is not logged in" do
      it "redirects to home with an alert" do
        get :track_journey
        expect(response).to redirect_to(home_path)
        expect(flash[:alert]).to eq("You must log in with Spotify to see your Track Journey.")
      end
    end

    context "when user IS logged in" do
      include_context "logged in user"

      it "loads grouped_by_badge and time_ranges" do
        mock = instance_double(TrackJourney)

        expect(TrackJourney).to receive(:new)
          .with(spotify_user_id: session_user["id"])
          .and_return(mock)

        allow(mock).to receive(:time_ranges).and_return([])
        allow(mock).to receive(:grouped_by_badge).and_return({})

        get :track_journey

        expect(assigns(:tracks_by_badge)).to eq({})
      end
    end
  end
end
