class PlaylistVectorService
  FEATURES = %w[energy danceability valence acousticness instrumentalness].freeze

  def initialize(features_client: ReccoBeatsClient)
    @features_client = features_client
  end

  def build_vector(tracks)
    track_ids = Array(tracks).map(&:id).compact
    return empty_result(track_ids.size) if track_ids.empty?

    feature_rows = fetch_feature_rows(track_ids)
    return empty_result(track_ids.size) if feature_rows.empty?

    sums = Hash.new(0.0)
    count = 0

    feature_rows.each do |row|
      valid = FEATURES.all? { |key| row[key].present? }
      next unless valid

      FEATURES.each do |key|
        sums[key] += row[key].to_f
      end
      count += 1
    end

    return empty_result(track_ids.size) if count.zero?

    vector = FEATURES.map { |key| (sums[key] / count.to_f).round(4) }

    {
      vector: vector,
      valid_count: count,
      total_tracks: track_ids.size
    }
  end

  private

  attr_reader :features_client

  def fetch_feature_rows(track_ids)
    Array(features_client.fetch_audio_features(track_ids)).map do |feat|
      {
        "spotify_id" => feat["spotify_id"] || feat[:spotify_id] || feat["id"] || feat[:id],
        "energy" => feat["energy"] || feat[:energy],
        "danceability" => feat["danceability"] || feat[:danceability],
        "valence" => feat["valence"] || feat[:valence],
        "acousticness" => feat["acousticness"] || feat[:acousticness],
        "instrumentalness" => feat["instrumentalness"] || feat[:instrumentalness]
      }
    end
  end

  def empty_result(total_tracks)
    { vector: nil, valid_count: 0, total_tracks: total_tracks }
  end
end
