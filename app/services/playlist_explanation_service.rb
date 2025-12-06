class PlaylistExplanationService
  FeatureDiff = Struct.new(:feature, :diff)

  SIMILARITY_BUCKETS = [
    { threshold: 0.1, label: "Very similar" },
    { threshold: 0.25, label: "Moderately similar" },
    { threshold: Float::INFINITY, label: "Different" }
  ].freeze

  FRIENDLY_FEATURES = {
    "energy" => "energy",
    "danceability" => "danceability",
    "valence" => "mood",
    "acousticness" => "acoustic feel",
    "instrumentalness" => "instrumental feel"
  }.freeze

  def initialize(vector_a:, vector_b:)
    @vector_a = vector_a
    @vector_b = vector_b
  end

  def explanations
    return [] if vector_a.nil? || vector_b.nil?

    diffs = build_diffs
    return [] if diffs.empty?

    similar, different = partition_diffs(diffs)

    messages = []
    if similar.any?
      top_similar = similar.first(2).map { |d| friendly_feature(d.feature) }
      messages << "Both playlists feel aligned on #{top_similar.to_sentence}."
    end

    if different.any?
      top_diff = different.first
      messages << "One playlist leans more on #{friendly_feature(top_diff.feature)}."
    end

    messages
  end

  private

  attr_reader :vector_a, :vector_b

  def build_diffs
    return [] if vector_a.size != vector_b.size

    PlaylistVectorService::FEATURES.each_with_index.map do |feature, idx|
      FeatureDiff.new(feature, (vector_a[idx].to_f - vector_b[idx].to_f).abs)
    end.sort_by(&:diff)
  end

  def partition_diffs(diffs)
    similar = []
    different = []

    diffs.each do |d|
      bucket = bucket_for(d.diff)
      if bucket == "Very similar" || bucket == "Moderately similar"
        similar << d
      else
        different << d
      end
    end

    [ similar, different ]
  end

  def bucket_for(diff)
    SIMILARITY_BUCKETS.find { |b| diff <= b[:threshold] }[:label]
  end

  def friendly_feature(key)
    FRIENDLY_FEATURES[key] || key
  end
end
