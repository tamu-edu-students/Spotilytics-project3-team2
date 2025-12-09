# spec/controllers/search_controller_spec.rb
require "rails_helper"

RSpec.describe SearchController, type: :controller do
  let(:mock_client) { instance_double(SpotifyClient) }

  before do
    # Don’t let the before_action block tests
    allow(controller).to receive(:require_spotify_auth!).and_return(true)
    # Stub the helper that builds the client
    allow(controller).to receive(:spotify_client).and_return(mock_client)
  end

  describe "GET #index" do
    context "when query param is present" do
      let(:query) { "Daft Punk" }
      let(:results_hash) do
        {
          artists: [ { "id" => "a1" } ],
          tracks:  [ { "id" => "t1" } ],
          albums:  [ { "id" => "al1" } ]
        }
      end

      before do
        allow(mock_client).to receive(:search).with(query).and_return(results_hash)
      end

      it "calls SpotifyClient.search and assigns results" do
        get :index, params: { query: query }

        expect(mock_client).to have_received(:search).with(query)

        expect(assigns(:artists)).to eq(results_hash[:artists])
        expect(assigns(:tracks)).to  eq(results_hash[:tracks])
        expect(assigns(:albums)).to  eq(results_hash[:albums])

        expect(assigns(:results)).to eq(
          artists: results_hash[:artists],
          tracks:  results_hash[:tracks],
          albums:  results_hash[:albums]
        )

        expect(response).to have_http_status(:ok)
      end
    end

    context "when only q param is present (backward compatibility)" do
      let(:query) { "Radiohead" }
      let(:results_hash) do
        {
          artists: [ { "id" => "a2" } ],
          tracks:  [ { "id" => "t2" } ],
          albums:  [ { "id" => "al2" } ]
        }
      end

      before do
        allow(mock_client).to receive(:search).with(query).and_return(results_hash)
      end

      it "uses q param as query and assigns results" do
        get :index, params: { q: query }

        expect(mock_client).to have_received(:search).with(query)

        expect(assigns(:artists)).to eq(results_hash[:artists])
        expect(assigns(:tracks)).to  eq(results_hash[:tracks])
        expect(assigns(:albums)).to  eq(results_hash[:albums])

        expect(assigns(:results)).to eq(
          artists: results_hash[:artists],
          tracks:  results_hash[:tracks],
          albums:  results_hash[:albums]
        )

        expect(response).to have_http_status(:ok)
      end
    end

    context "when query is blank or missing" do
      it "does not call SpotifyClient.search and simply renders" do
        expect(mock_client).not_to receive(:search)

        get :index, params: { query: "   " }

        expect(assigns(:artists)).to be_nil
        expect(assigns(:tracks)).to  be_nil
        expect(assigns(:albums)).to  be_nil
        expect(assigns(:results)).to be_nil

        expect(response).to have_http_status(:ok)
      end
    end

    context "when SpotifyClient raises UnauthorizedError" do
      before do
        allow(mock_client).to receive(:search)
          .and_raise(SpotifyClient::UnauthorizedError.new("expired"))
      end

      it "redirects to login_path with an alert" do
        get :index, params: { query: "something" }

        expect(response).to redirect_to(login_path)
        expect(flash[:alert]).to eq("Spotify session expired. Please sign in again.")
      end
    end

    context "when a generic error occurs" do
      before do
        allow(mock_client).to receive(:search)
          .and_raise(StandardError.new("something went wrong"))
      end

      it "assigns empty arrays and renders successfully" do
        get :index, params: { query: "something" }

        expect(assigns(:artists)).to eq([])
        expect(assigns(:tracks)).to  eq([])
        expect(assigns(:albums)).to  eq([])
        expect(assigns(:results)).to eq(
          artists: [],
          tracks:  [],
          albums:  []
        )

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
