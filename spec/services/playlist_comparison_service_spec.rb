require "rails_helper"

RSpec.describe PlaylistComparisonService do
  let(:client) { instance_double(SpotifyClient) }
  let(:vector_service) { instance_double(PlaylistVectorService) }
  let(:service) { described_class.new(client: client, vector_service: vector_service) }

  def track(id)
    OpenStruct.new(id: id, name: "Track #{id}", artists: "Artist")
  end

  describe "#compare" do
    it "computes overlap and compatibility" do
      tracks_a = [ track("1"), track("2"), track("3") ]
      tracks_b = [ track("2"), track("3"), track("4") ]

      expect(client).to receive(:playlist_tracks).with(playlist_id: "a", limit: 200).and_return(tracks_a)
      expect(client).to receive(:playlist_tracks).with(playlist_id: "b", limit: 200).and_return(tracks_b)

      expect(vector_service).to receive(:build_vector).with(tracks_a).and_return({ vector: [ 1, 0, 0, 0, 0 ], valid_count: 5, total_tracks: 3 })
      expect(vector_service).to receive(:build_vector).with(tracks_b).and_return({ vector: [ 1, 0, 0, 0, 0 ], valid_count: 5, total_tracks: 3 })

      result = service.compare(source_playlist_id: "a", target_playlist_id: "b")

      expect(result.overlap_count).to eq(2)
      expect(result.overlap_pct).to eq(66.7)
      expect(result.compatibility).to eq(100)
      expect(result.common_tracks.map(&:id)).to match_array([ "2", "3" ])
    end

    it "returns nil compatibility when insufficient data" do
      tracks_a = [ track("1"), track("2") ]
      tracks_b = [ track("3"), track("4") ]

      allow(client).to receive(:playlist_tracks).and_return(tracks_a, tracks_b)
      allow(vector_service).to receive(:build_vector).and_return({ vector: [ 1, 0, 0, 0, 0 ], valid_count: 2, total_tracks: 2 })

      result = service.compare(source_playlist_id: "a", target_playlist_id: "b")
      expect(result.compatibility).to be_nil
    end
  end
end
