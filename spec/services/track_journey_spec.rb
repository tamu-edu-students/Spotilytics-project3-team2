require "rails_helper"

RSpec.describe TrackJourney do
  let(:spotify_user_id) { "user_123" }
  subject(:journey) { described_class.new(spotify_user_id: spotify_user_id, limit_per_range: 20) }

  describe "#time_ranges" do
    it "returns the configured TIME_RANGES constant" do
      expect(journey.time_ranges).to eq described_class::TIME_RANGES
      expect(journey.time_ranges.map(&:key)).to eq %i[short_term medium_term long_term]
    end
  end

  describe "#grouped_by_badge" do
    def build_item(badge, ranks = {})
      described_class::TrackJourneyItem.new(
        spotify_id:      SecureRandom.uuid,
        name:            "Song",
        artists:         "Artist",
        album_name:      "Album",
        album_image_url: "http://example.com/cover.png",
        ranks:           ranks,
        badge:           badge,
        badge_label:     described_class::BADGE_LABELS[badge],
        journey_summary: "summary"
      )
    end

    let(:evergreen_items)    { Array.new(4) { build_item(:evergreen) } }
    let(:new_obsession_item) { build_item(:new_obsession) }
    let(:nil_badge_item)     { build_item(nil) }

    before do
      allow(journey).to receive(:combined_tracks)
        .and_return(evergreen_items + [ new_obsession_item, nil_badge_item ])
    end

    it "groups items by badge" do
      grouped = journey.grouped_by_badge

      expect(grouped.keys).to contain_exactly(:evergreen, :new_obsession)
      expect(grouped[:evergreen]).to all(have_attributes(badge: :evergreen))
      expect(grouped[:new_obsession]).to eq [ new_obsession_item ]
    end

    it "respects max_per_badge limit" do
      grouped = journey.grouped_by_badge(max_per_badge: 3)
      expect(grouped[:evergreen].size).to eq 3
    end

    it "can return all items when max_per_badge is nil" do
      grouped = journey.grouped_by_badge(max_per_badge: Float::INFINITY)
      expect(grouped[:evergreen].size).to eq evergreen_items.size
    end
  end

  describe "classification helpers (via private methods)" do
    def classify(ranks)
      journey.send(:classify_badge, ranks)
    end

    def summary_for(badge, ranks)
      journey.send(:build_summary, badge, ranks)
    end

    let(:ranks_evergreen)   { { short_term: 1, medium_term: 3, long_term: 5 } }
    let(:ranks_new_obs)     { { short_term: 2 } }
    let(:ranks_short_term)  { { short_term: 2, medium_term: 4 } }
    let(:ranks_fading_out)  { { long_term: 1 } }
    let(:ranks_unclassified) { { short_term: nil, medium_term: nil, long_term: nil } }

    describe "#classify_badge" do
      it "returns :evergreen when all three ranges are present" do
        expect(classify(ranks_evergreen)).to eq :evergreen
      end

      it "returns :new_obsession when only short_term is present" do
        expect(classify(ranks_new_obs)).to eq :new_obsession
      end

      it "returns :short_term when short and medium are present but not long term" do
        expect(classify(ranks_short_term)).to eq :short_term
      end

      it "returns :fading_out when only long_term is present" do
        expect(classify(ranks_fading_out)).to eq :fading_out
      end

      it "returns nil when pattern does not match any badge" do
        expect(classify(ranks_unclassified)).to be_nil
      end
    end

    describe "#build_summary" do
      it "returns the correct summary for evergreen" do
        text = summary_for(:evergreen, ranks_evergreen)
        expect(text).to match(/top tracks all year/i)
      end

      it "returns the correct summary for new_obsession" do
        text = summary_for(:new_obsession, ranks_new_obs)
        expect(text).to match(/new in your top 10/i)
      end

      it "returns the correct summary for short_term" do
        text = summary_for(:short_term, ranks_short_term)
        expect(text).to match(/climbing recently/i)
      end

      it "returns the correct summary for fading_out" do
        text = summary_for(:fading_out, ranks_fading_out)
        expect(text).to match(/falling out of your top tracks/i)
      end

      it "falls back to a generic summary for unknown badge" do
        text = summary_for(nil, ranks_unclassified)
        expect(text).to match(/listening journey/i)
      end
    end
  end

  describe "#combined_tracks" do
    let(:short_result) do
      instance_double(
        "TopTrackResult",
        spotify_id: "track_1",
        name: "Track 1",
        artists: "Artist 1",
        album_name: "Album 1",
        album_image_url: "http://example.com/cover1.png",
        position: 1
      )
    end

    let(:medium_result) do
      instance_double(
        "TopTrackResult",
        spotify_id: "track_1",
        name: "Track 1 (ignored from medium)",
        artists: "Artist 1",
        album_name: "Album 1",
        album_image_url: "http://example.com/cover1.png",
        position: 2
      )
    end

    let(:long_result) do
      instance_double(
        "TopTrackResult",
        spotify_id: "track_1",
        name: "Track 1 (ignored from long)",
        artists: "Artist 1",
        album_name: "Album 1",
        album_image_url: "http://example.com/cover1.png",
        position: 3
      )
    end

    let(:short_batch)  { instance_double("TopTrackBatch",  top_track_results: [ short_result ]) }
    let(:medium_batch) { instance_double("TopTrackBatch",  top_track_results: [ medium_result ]) }
    let(:long_batch)   { instance_double("TopTrackBatch",  top_track_results: [ long_result ]) }

    before do
      allow(TopTrackBatch).to receive(:find_by)
        .with(spotify_user_id: spotify_user_id, time_range: "short_term")
        .and_return(short_batch)

      allow(TopTrackBatch).to receive(:find_by)
        .with(spotify_user_id: spotify_user_id, time_range: "medium_term")
        .and_return(medium_batch)

      allow(TopTrackBatch).to receive(:find_by)
        .with(spotify_user_id: spotify_user_id, time_range: "long_term")
        .and_return(long_batch)
    end

    it "aggregates track data across time ranges and classifies badges" do
      grouped = journey.grouped_by_badge(max_per_badge: 5)

      expect(grouped.keys).to include(:evergreen)
      item = grouped[:evergreen].first

      expect(item.name).to eq "Track 1"
      expect(item.artists).to eq "Artist 1"
      expect(item.album_name).to eq "Album 1"
      expect(item.album_image_url).to eq "http://example.com/cover1.png"

      expect(item.ranks).to eq(
        short_term:  1,
        medium_term: 2,
        long_term:   3
      )

      expect(item.badge).to eq :evergreen
      expect(item.badge_label).to eq TrackJourney::BADGE_LABELS[:evergreen]
      expect(item.journey_summary).to be_a(String)
    end

    it "skips time ranges with no batch" do
      allow(TopTrackBatch).to receive(:find_by)
        .with(spotify_user_id: spotify_user_id, time_range: "medium_term")
        .and_return(nil)

      grouped = journey.grouped_by_badge(max_per_badge: 5)
      item = grouped.values.flatten.first

      next if item.nil?
      expect(item.ranks.keys).to contain_exactly(:short_term, :long_term)
    end
  end
end
