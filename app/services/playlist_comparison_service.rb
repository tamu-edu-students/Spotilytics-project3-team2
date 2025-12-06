class PlaylistComparisonService
  CompatibilityResult = Struct.new(
    :compatibility,
    :overlap_count,
    :overlap_pct,
    :common_tracks,
    :only_in_a,
    :only_in_b,
    :vector_a,
    :vector_b,
    :valid_a,
    :valid_b,
    :flags,
    keyword_init: true
  )

  def initialize(client:, vector_service: PlaylistVectorService.new)
    @client = client
    @vector_service = vector_service
  end

  def compare(source_playlist_id:, target_playlist_id:)
    tracks_a = client.playlist_tracks(playlist_id: source_playlist_id, limit: 200)
    tracks_b = client.playlist_tracks(playlist_id: target_playlist_id, limit: 200)

    overlap_info = compute_overlap(tracks_a, tracks_b)

    vector_info_a = vector_service.build_vector(tracks_a)
    vector_info_b = vector_service.build_vector(tracks_b)

    compatibility = compute_compatibility(vector_info_a[:vector], vector_info_b[:vector], vector_info_a[:valid_count], vector_info_b[:valid_count])

    CompatibilityResult.new(
      compatibility: compatibility,
      overlap_count: overlap_info[:count],
      overlap_pct: overlap_info[:pct],
      common_tracks: overlap_info[:common],
      only_in_a: overlap_info[:only_in_a],
      only_in_b: overlap_info[:only_in_b],
      vector_a: vector_info_a[:vector],
      vector_b: vector_info_b[:vector],
      valid_a: vector_info_a[:valid_count],
      valid_b: vector_info_b[:valid_count],
      flags: overlap_info[:flags]
    )
  end

  private

  attr_reader :client, :vector_service

  def compute_overlap(tracks_a, tracks_b)
    ids_a = Array(tracks_a).map(&:id).compact
    ids_b = Array(tracks_b).map(&:id).compact

    set_a = ids_a.to_set
    set_b = ids_b.to_set

    common_ids = set_a & set_b
    min_size = [ set_a.size, set_b.size ].min
    pct = if min_size.zero?
      0
    else
      (common_ids.size.to_f / min_size.to_f * 100).round(1)
    end

    {
      count: common_ids.size,
      pct: pct,
      common: Array(tracks_a).select { |t| common_ids.include?(t.id) },
      only_in_a: Array(tracks_a).reject { |t| common_ids.include?(t.id) },
      only_in_b: Array(tracks_b).reject { |t| common_ids.include?(t.id) },
      flags: []
    }
  end

  def compute_compatibility(vector_a, vector_b, valid_a, valid_b)
    return nil if vector_a.nil? || vector_b.nil?
    return nil if valid_a.to_i < 5 || valid_b.to_i < 5

    dot = vector_a.zip(vector_b).sum { |a, b| a.to_f * b.to_f }
    mag_a = Math.sqrt(vector_a.sum { |v| v.to_f ** 2 })
    mag_b = Math.sqrt(vector_b.sum { |v| v.to_f ** 2 })
    return nil if mag_a.zero? || mag_b.zero?

    similarity = dot / (mag_a * mag_b)
    return nil if similarity.nan?

    (similarity * 100).round
  end
end
