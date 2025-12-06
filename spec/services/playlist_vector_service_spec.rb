require "rails_helper"

RSpec.describe PlaylistVectorService do
  let(:features_client) { class_double(ReccoBeatsClient) }
  let(:service) { described_class.new(features_client: features_client) }

  describe "#build_vector" do
    it "averages features and returns metadata" do
      tracks = [
        OpenStruct.new(id: "a"),
        OpenStruct.new(id: "b")
      ]
      allow(features_client).to receive(:fetch_audio_features).with([ "a", "b" ]).and_return([
        { "id" => "a", "energy" => 0.5, "danceability" => 0.4, "valence" => 0.3, "acousticness" => 0.2, "instrumentalness" => 0.1 },
        { "id" => "b", "energy" => 1.0, "danceability" => 0.8, "valence" => 0.6, "acousticness" => 0.4, "instrumentalness" => 0.2 }
      ])

      result = service.build_vector(tracks)

      expect(result[:vector]).to eq([ 0.75, 0.6, 0.45, 0.3, 0.15 ])
      expect(result[:valid_count]).to eq(2)
      expect(result[:total_tracks]).to eq(2)
    end

    it "returns nil vector when no valid features" do
      tracks = [ OpenStruct.new(id: "a") ]
      allow(features_client).to receive(:fetch_audio_features).and_return([])

      result = service.build_vector(tracks)

      expect(result[:vector]).to be_nil
      expect(result[:valid_count]).to eq(0)
      expect(result[:total_tracks]).to eq(1)
    end
  end
end
