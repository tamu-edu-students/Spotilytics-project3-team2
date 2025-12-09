require "rails_helper"

RSpec.describe ListeningPatternsController, type: :controller do
  # --- SETUP & SHARED MOCKS ---

  let(:spotify_user_id) { "spotify-user-1" }
  let(:session_user) do
    {
      "id"           => spotify_user_id,
      "display_name" => "Test Listener",
      "email"        => "listener@example.com",
      "image"        => "http://example.com/user.jpg"
    }
  end

  # Paths are needed for redirect assertions
  before do
    session[:spotify_user] = session_user
    allow(controller).to receive(:home_path).and_return('/home')
    allow(controller).to receive(:login_path).and_return('/login')
  end

  # Mock API/History for all actions
  let(:mock_client) { instance_double(SpotifyClient) }
  let(:mock_history) { instance_double(ListeningHistory) }

  before do
    allow(SpotifyClient).to receive(:new).with(session: anything).and_return(mock_client)
    allow(ListeningHistory).to receive(:new).with(spotify_user_id: spotify_user_id).and_return(mock_history)
  end

  # Shared error contexts for cleaner code
  shared_examples 'handles generic spotify error' do |action|
    let(:generic_error) { SpotifyClient::Error.new('Rate limit exceeded') }

    before do
      # Mock the method that triggers the API call for the specific action
      if action == :monthly
        allow(stats_service).to receive(:chart_data).and_raise(generic_error)
      else
        allow(mock_client).to receive(:recently_played).and_raise(generic_error)
      end
      allow(Rails.logger).to receive(:warn)
    end

    it 'logs a warning and sets a flash.now alert' do
      get action
      expect(Rails.logger).to have_received(:warn).with(/Failed to fetch/)
      expect(flash.now[:alert]).to eq("We weren't able to load your listening history from Spotify right now.")
    end
  end

  # --- GET #hourly ---

  describe "GET #hourly" do
    let(:plays) do
      [
        # Should result in 10 AM and 11 AM UTC (5 AM and 6 AM CST)
        OpenStruct.new(id: "t1", name: "One", artists: "A", played_at: Time.utc(2025, 1, 1, 10, 0, 0)),
        OpenStruct.new(id: "t2", name: "Two", artists: "B", played_at: Time.utc(2025, 1, 1, 11, 0, 0)),
        OpenStruct.new(id: "t3", name: "Three", artists: "C", played_at: Time.utc(2025, 1, 1, 10, 30, 0)) # 10 AM UTC
      ]
    end

    # Mock ingest call for error handling
    before do
      allow(mock_history).to receive(:ingest!)
      allow(mock_client).to receive(:recently_played)
    end

    context "when Spotify data loads successfully" do
      # Setup time zone for predictable charting
      before do
        Time.zone = 'America/Chicago'
        allow(mock_client).to receive(:recently_played).and_return(plays)
        allow(mock_history).to receive(:recent_entries).and_return(plays)
      end
      after { Time.zone = nil }

      it "assigns chart data with correct time zone conversion" do
        get :hourly, params: { limit: 50 }

        expect(response).to have_http_status(:ok)
        expect(assigns(:sample_size)).to eq(3)
        expect(assigns(:total_plays)).to eq(3)

        # Check time zone conversion (10 UTC and 11 UTC are 5 CST and 6 CST)

        # Top hours should reflect the CST hours (5 AM and 6 AM)
        expect(assigns(:top_hours).first[:hour]).to eq(4)
      end

      it "uses default limit of 100 if invalid limit is passed" do
        expect(mock_history).to receive(:recent_entries).with(limit: 100).and_return(plays)
        get :hourly, params: { limit: 999 }
        expect(assigns(:limit)).to eq(100)
      end
    end

    context "when Spotify requires re-authentication" do
      before do
        allow(mock_client).to receive(:recently_played).and_raise(SpotifyClient::UnauthorizedError.new("expired"))
      end

      it "redirects to home with alert" do
        get :hourly
        expect(response).to redirect_to(home_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when Spotify returns insufficient scope" do
      before do
        session[:spotify_token] = "t"
        allow(mock_client).to receive(:recently_played).and_raise(
          SpotifyClient::Error.new("Insufficient client scope")
        )
      end

      it "resets session tokens and redirects to login" do
        get :hourly
        expect(response).to redirect_to(login_path)
        expect(session[:spotify_token]).to be_nil
      end
    end

    context "when a generic Spotify error occurs" do
      it_behaves_like 'handles generic spotify error', :hourly

      it 'assigns nil/empty fallbacks on error' do
        allow(mock_client).to receive(:recently_played).and_raise(SpotifyClient::Error.new('Generic error'))
        get :hourly
        expect(assigns(:sample_size)).to eq(0)
        expect(assigns(:hourly_chart)).to be_nil
        expect(assigns(:top_hours)).to eq([])
      end
    end

    context "when user is not logged in (before_action fail)" do
      before { session.delete(:spotify_user) }

      it "redirects to home" do
        get :hourly
        expect(response).to redirect_to(home_path)
        expect(flash[:alert]).to eq("You must log in with spotify to view this page.")
      end
    end
  end

  # --- GET #calendar ---

  describe "GET #calendar" do
    let(:plays) do
      [
        OpenStruct.new(id: "t1", played_at: Time.utc(2025, 1, 1, 10, 0, 0)), # Jan 1
        OpenStruct.new(id: "t2", played_at: Time.utc(2025, 1, 1, 11, 0, 0)), # Jan 1
        OpenStruct.new(id: "t3", played_at: Time.utc(2025, 1, 2, 12, 0, 0)) # Jan 2
      ]
    end

    # Mock ingest call for error handling
    before do
      allow(mock_history).to receive(:ingest!)
      allow(mock_client).to receive(:recently_played)
    end

    context "when Spotify data loads successfully" do
      before do
        # Use a fixed today's date for consistent calendar grid building
        allow(Date).to receive(:today).and_return(Date.new(2025, 1, 5)) # Sunday
        allow(mock_client).to receive(:recently_played).and_return(plays)
        allow(mock_history).to receive(:recent_entries).with(limit: 500).and_return(plays)
      end
      after { allow(Date).to receive(:today).and_call_original }
    end

    context "when Spotify requires re-authentication" do
      before do
        allow(mock_client).to receive(:recently_played).and_raise(SpotifyClient::UnauthorizedError.new("expired"))
      end

      it "redirects to home with alert" do
        get :calendar
        expect(response).to redirect_to(home_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when a generic Spotify error occurs" do
      it_behaves_like 'handles generic spotify error', :calendar

      it 'assigns nil/empty fallbacks on error' do
        allow(mock_client).to receive(:recently_played).and_raise(SpotifyClient::Error.new('Generic error'))
        get :calendar
        expect(assigns(:sample_size)).to eq(0)
        expect(assigns(:weeks)).to eq([])
      end
    end
  end

  # --- GET #monthly ---

  describe "GET #monthly" do
    let(:stats_service) { instance_double(MonthlyListeningStats) }
    let(:chart_summary) do
      {
        chart: { labels: [ "Dec 2024", "Jan 2025" ] },
        buckets: [
          { label: "Dec 2024", month: Time.utc(2024, 12, 1), duration_ms: 7_200_000 },
          { label: "Jan 2025", month: Time.utc(2025, 1, 1), duration_ms: 5_400_000 }
        ],
        sample_size: 70,
        total_duration_ms: 12_600_000,
        history_window: [ Time.utc(2024, 12, 1), Time.utc(2025, 1, 31) ]
      }
    end

    before do
      allow(MonthlyListeningStats).to receive(:new).with(client: mock_client, time_zone: Time.zone).and_return(stats_service)
    end

    context "when Spotify data loads successfully" do
      before do
        allow(stats_service).to receive(:chart_data).with(limit: 500).and_return(chart_summary)
      end

      it "assigns data variables correctly" do
        get :monthly

        expect(response).to have_http_status(:ok)
        expect(assigns(:chart_data)).to be_present
        expect(assigns(:sample_size)).to eq(70)
        expect(assigns(:total_hours)).to eq(3.5) # 12,600,000 ms / 3,600,000 ms/hr = 3.5 hrs
        expect(assigns(:previous_month)).to eq(chart_summary[:buckets].first)
      end

      it "uses default limit of 500 when no limit is present" do
        expect(stats_service).to receive(:chart_data).with(limit: 500).and_return(chart_summary)
        get :monthly
      end

      it "uses provided limit if present" do
        expect(stats_service).to receive(:chart_data).with(limit: 250).and_return(chart_summary)
        get :monthly, params: { limit: 250 }
        expect(assigns(:limit)).to eq(250)
      end
    end

    context "when Spotify requires re-authentication" do
      before do
        allow(stats_service).to receive(:chart_data).and_raise(SpotifyClient::UnauthorizedError.new("expired"))
      end

      it "redirects to home with alert" do
        get :monthly
        expect(response).to redirect_to(home_path)
        expect(flash[:alert]).to be_present
      end
    end

    context "when a generic Spotify error occurs" do
      let(:generic_error) { SpotifyClient::Error.new('API timeout') }

      it_behaves_like 'handles generic spotify error', :monthly

      it 'assigns nil/empty fallbacks on error' do
        allow(stats_service).to receive(:chart_data).and_raise(generic_error)
        get :monthly
        expect(assigns(:sample_size)).to eq(0)
        expect(assigns(:chart_data)).to be_nil
        expect(assigns(:total_hours)).to eq(0)
      end
    end
  end

  # --- PRIVATE UTILITY METHOD TESTS ---

  describe 'Private Utility Methods' do
    # Using controller.send to access private methods for unit testing

    describe '#normalize_limit' do
      it 'returns the value if it is valid' do
        expect(controller.send(:normalize_limit, 50)).to eq(50)
      end

      it 'defaults to 100 if the value is invalid' do
        expect(controller.send(:normalize_limit, 75)).to eq(100)
      end
    end

    describe '#hour_label' do
      it 'formats 0 (midnight) correctly' do
        expect(controller.send(:hour_label, 0)).to eq('12 AM')
      end
      it 'formats 12 (noon) correctly' do
        expect(controller.send(:hour_label, 12)).to eq('12 PM')
      end
      it 'formats 17 (5 PM) correctly' do
        expect(controller.send(:hour_label, 17)).to eq('5 PM')
      end
    end

    describe '#intensity_level' do
      it 'returns 4 for high intensity (> 75%)' do
        expect(controller.send(:intensity_level, 8, 10)).to eq(4)
      end
      it 'returns 1 for low intensity (0-25%)' do
        expect(controller.send(:intensity_level, 2, 10)).to eq(1)
      end
    end

    describe '#hours_from_ms' do
      it 'converts milliseconds to hours rounded to one decimal place' do
        # 1 hour = 3,600,000 ms
        expect(controller.send(:hours_from_ms, 3_600_000)).to eq(1.0)
        # 10 hours and 15 minutes = 36,900,000 ms
        expect(controller.send(:hours_from_ms, 36_900_000)).to eq(10.3)
      end
    end
  end
end
