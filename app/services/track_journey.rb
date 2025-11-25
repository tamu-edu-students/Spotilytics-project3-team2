class TrackJourney
  TimeRange = Struct.new(:key, :label, :db_value, keyword_init: true)

  TIME_RANGES = [
    TimeRange.new(key: :short_term,  label: "Last 4 weeks",   db_value: "short_term"),
    TimeRange.new(key: :medium_term, label: "Last 6 months",  db_value: "medium_term"),
    TimeRange.new(key: :long_term,   label: "Last year",      db_value: "long_term")
  ].freeze

  TrackJourneyItem = Struct.new(
    :spotify_id,
    :name,
    :artists,
    :album_name,
    :album_image_url,
    :ranks,
    :badge,
    :badge_label,
    :journey_summary,
    keyword_init: true
  )

  BADGE_LABELS = {
    evergreen:      "Evergreen",
    new_obsession:  "New Obsession",
    short_term:     "Short-Term Crush",
    fading_out:     "Fading Out"
  }.freeze

  attr_reader :spotify_user_id, :limit_per_range

  def initialize(spotify_user_id:, limit_per_range: 20)
    @spotify_user_id = spotify_user_id
    @limit_per_range = limit_per_range
  end

  def grouped_by_badge(max_per_badge: 3)
    items_by_badge = Hash.new { |h, k| h[k] = [] }

    combined_tracks.each do |item|
      next unless item.badge

      if items_by_badge[item.badge].size < max_per_badge
        items_by_badge[item.badge] << item
      end
    end

    items_by_badge
  end

  def time_ranges
    TIME_RANGES
  end

  private

  def combined_tracks
    @combined_tracks ||= begin
      by_spotify_id = Hash.new { |h, k| h[k] = { data: nil, ranks: {} } }

      TIME_RANGES.each do |range|
        batch = TopTrackBatch.find_by(
          spotify_user_id: spotify_user_id,
          time_range: range.db_value
        )

        next unless batch

        batch.top_track_results.each do |row|
          container = by_spotify_id[row.spotify_id]

          container[:data] ||= {
            spotify_id:       row.spotify_id,
            name:             row.name,
            artists:          row.artists,
            album_name:       row.album_name,
            album_image_url:  row.album_image_url
          }

          container[:ranks][range.key] = row.position
        end
      end

      by_spotify_id.map do |_spotify_id, payload|
        ranks = payload[:ranks]
        badge = classify_badge(ranks)
        TrackJourneyItem.new(
          **payload[:data],
          ranks: ranks,
          badge: badge,
          badge_label: BADGE_LABELS[badge],
          journey_summary: build_summary(badge, ranks)
        )
      end.compact
    end
  end

  def classify_badge(ranks)
    s = ranks[:short_term]
    m = ranks[:medium_term]
    l = ranks[:long_term]

    if s && m && l
      return :evergreen
    end

    if s && m.nil? && l.nil?
      return :new_obsession
    end

    if s && m && l.nil?
      return :short_term
    end

    if l && s.nil?
      return :fading_out
    end

    nil
  end

  def build_summary(badge, ranks)
    s = ranks[:short_term]
    m = ranks[:medium_term]
    l = ranks[:long_term]

    case badge
    when :evergreen
      "In your top tracks all year long"
    when :new_obsession
      "New in your top 10 this month"
    when :short_term
      "Climbing recently but wasn’t around last year"
    when :fading_out
      "Used to be a favorite, now falling out of your top tracks"
    else
      "Part of your listening journey"
    end
  end
end
