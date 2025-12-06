require "rails_helper"

RSpec.describe SpotifyClient, type: :service do
  let(:session) { { spotify_user: { "id" => "user1" }, spotify_token: "tok" } }
  let(:client)  { described_class.new(session: session) }

  before do
    allow(client).to receive(:ensure_access_token!).and_return("tok")
  end

  it "fetches playlist tracks with pagination" do
    first_page_items = Array.new(100) do |i|
      { "track" => { "id" => "t#{i+1}", "name" => "Track #{i+1}", "artists" => [ { "name" => "A" } ], "duration_ms" => 1000, "external_urls" => { "spotify" => "url#{i+1}" } } }
    end
    first_page = { "items" => first_page_items }
    second_page = {
      "items" => [
        { "track" => { "id" => "t101", "name" => "Track 101", "artists" => [ { "name" => "B" } ], "duration_ms" => 2000, "external_urls" => { "spotify" => "url101" } } }
      ]
    }

    expect(client).to receive(:get).with("/playlists/pl123/tracks", "tok", limit: 100, offset: 0).and_return(first_page)
    expect(client).to receive(:get).with("/playlists/pl123/tracks", "tok", limit: 1, offset: 100).and_return(second_page)

    tracks = client.playlist_tracks(playlist_id: "pl123", limit: 101)
    expect(tracks.first.id).to eq("t1")
    expect(tracks.last.id).to eq("t101")
    expect(tracks.last.spotify_url).to eq("url101")
  end
end
