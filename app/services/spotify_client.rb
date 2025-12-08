# frozen_string_literal: true

require "net/http"
require "uri"
require "json"
require "base64"
require "ostruct"
require "set"
require "time"
require "digest"

class SpotifyClient
  API_ROOT = "https://api.spotify.com/v1"
  TOKEN_URI = URI("https://accounts.spotify.com/api/token").freeze
  RECENTLY_PLAYED_CACHE_VERSION = "v2"

  class Error < StandardError; end
  class UnauthorizedError < Error; end

  def initialize(session:)
    @session = session
    @client_id = ENV["SPOTIFY_CLIENT_ID"]
    @client_secret = ENV["SPOTIFY_CLIENT_SECRET"]
  end
  def user_playlists(limit: 50)
      access_token = ensure_access_token!
      response = get("/me/playlists", access_token, limit: limit)
      items = response.fetch("items", [])
      items.map do |p|
        OpenStruct.new(
          id: p["id"],
          name: p["name"],
          description: p["description"],
          owner_id: p.dig("owner", "id"),
          tracks_count: p.dig("tracks", "total"),
          spotify_url: p.dig("external_urls", "spotify"),
          image_url: p.dig("images", 0, "url")
        )
      end
    end
  def get_playlist(id)
    access_token = ensure_access_token!
    get("/playlists/#{id}", access_token)
  end

  # Return playlist tracks enriched with first-artist genres
  # Returns array of hashes:
  # { id:, name:, artists:, album_name:, album_image_url:, preview_url:, spotify_url:, genres: [] }
  def playlist_tracks_with_genres(playlist_id, limit: 100)
    access_token = ensure_access_token!

    # fetch playlist tracks
    response = get("/playlists/#{playlist_id}/tracks", access_token, limit: limit)
    items = Array(response["items"])

    # collect all artist ids to do a batched artists lookup
    artist_ids = items.flat_map do |it|
      track = it["track"] || {}
      (track["artists"] || []).map { |a| a["id"] }
    end.compact.uniq

    artist_genres_map = {}

    if artist_ids.any?
      artist_ids.each_slice(50) do |slice|
        artists_resp = get("/artists", access_token, ids: slice.join(","))
        (artists_resp["artists"] || []).each do |a|
          artist_genres_map[a["id"]] = (a["genres"] || [])
        end
      end
    end

    items.map do |it|
      track = it["track"] || {}
      artists = (track["artists"] || []).map { |a| a["name"] }.join(", ")

      first_artist_id = track.dig("artists", 0, "id")
      genres = artist_genres_map[first_artist_id] || []

      {
        id: track["id"],
        name: track["name"],
        artists: artists,
        album_name: track.dig("album", "name"),
        album_image_url: track.dig("album", "images", 0, "url"),
        preview_url: track["preview_url"],
        spotify_url: track.dig("external_urls", "spotify"),
        genres: genres
      }
    end
  end

  def search(query, limit: 10)
    access_token = ensure_access_token!

    params = {
      q: query,
      type: "artist,track,album",
      limit: limit
    }

    response = get("/search", access_token, params)

    {
      artists: response.dig("artists", "items") || [],
      tracks:  response.dig("tracks",  "items") || [],
      albums:  response.dig("albums",  "items") || []
    }
  end


  def search_tracks(query, limit: 10, max_age: 4.days)
    spotify_user_id = session.dig(:spotify_user, "id")

    search = TrackSearch
        .where(spotify_user_id: spotify_user_id, query: query, limit: limit)
        .fresh(max_age: max_age)
        .includes(:track_search_results)
        .first

    if search.present?
      return search.track_search_results
                  .sort_by(&:position)
                  .map { |r| build_track_from_row(r) }
    end

    access_token = ensure_access_token!
    params = {
      q: query,
      type: "track",
      limit: limit
    }

    response = get("/search", access_token, params)
    items = response.dig("tracks", "items") || []

    TrackSearch.transaction do
    search = TrackSearch.create!(
      spotify_user_id: spotify_user_id,
      query:        query,
      limit:        limit,
      fetched_at:   Time.current
    )

      items.each_with_index do |item, index|
        TrackSearchResult.create!(
          track_search:     search,
          position:         index + 1,
          spotify_id:       item["id"],
          name:             item["name"],
          artists:          (item["artists"] || []).map { |a| a["name"] }.join(", "),
          album_name:       item.dig("album", "name"),
          album_image_url:  item.dig("album", "images", 0, "url"),
          popularity:       item["popularity"],
          preview_url:      item["preview_url"],
          spotify_url:      item.dig("external_urls", "spotify"),
          duration_ms:      item["duration_ms"]
        )
      end
    end

    items.each_with_index.map do |item, index|
      OpenStruct.new(
        id: item["id"],
        name: item["name"],
        artists: (item["artists"] || []).map { |a| a["name"] }.join(", "),
        album_name: item.dig("album", "name"),
        album_image_url: item.dig("album", "images", 0, "url"),
        popularity: item["popularity"],
        preview_url: item["preview_url"],
        spotify_url: item.dig("external_urls", "spotify"),
        duration_ms: item["duration_ms"]
      )
    end
  end

  def profile
    access_token = ensure_access_token!
    response = get("/users/#{current_user_id}", access_token)

    items = OpenStruct.new(
      id: response["id"],
      display_name: response["display_name"],
      image_url: response.dig("images", 0, "url"),
      followers: response.dig("followers", "total") || 0,
      spotify_url: response.dig("external_urls", "spotify")
    )
  end

  def track_audio_features(ids)
    ids = Array(ids).map(&:to_s).reject(&:blank?).uniq.first(100)
    return {} if ids.empty?

    key = Digest::SHA1.hexdigest(ids.sort.join("-"))

    cache_for([ "audio_features", key ], expires_in: 2.hours) do
      access_token = ensure_access_token!
      features = {}

      ids.each_slice(50) do |slice|
        begin
          response = get("/audio-features", access_token, ids: slice.join(","))
          items = Array(response["audio_features"])
          items.each do |item|
            next unless item
            features[item["id"]] = OpenStruct.new(
              id: item["id"],
              danceability: item["danceability"],
              energy: item["energy"],
              valence: item["valence"],
              tempo: item["tempo"],
              acousticness: item["acousticness"],
              instrumentalness: item["instrumentalness"]
            )
          end
        rescue Error => e
          Rails.logger.warn "[Spotify] Skipping audio-features slice due to error: #{e.message}"
        end
      end

      features
    end
  end

  def new_releases(limit:, max_age: 1.day)
    batch = NewReleaseBatch.find_or_initialize_by(limit: limit)

    if batch.persisted? && batch.fetched_at.present? && batch.fetched_at >= max_age.ago
      Rails.logger.info "[NewReleases] cache HIT limit=#{limit}"

      return batch.new_releases
                  .order(:position)
                  .map { |r| build_new_release_from_row(r) }
    end

    Rails.logger.info "[NewReleases] cache MISS/STALE limit=#{limit}"

    access_token = ensure_access_token!
    response     = get("/browse/new-releases", access_token, limit: limit)
    items        = response.dig("albums", "items") || []

    NewReleaseBatch.transaction do
      batch.fetched_at = Time.current
      batch.save!

      batch.new_releases.delete_all

      items.each_with_index do |item, index|
        batch.new_releases.create!(
          position:      index + 1,
          spotify_id:    item["id"],
          name:          item["name"],
          image_url:     item.dig("images", 0, "url"),
          total_tracks:  item["total_tracks"] || 0,
          release_date:  item["release_date"] || "",
          spotify_url:   item.dig("external_urls", "spotify"),
          artists:       (item["artists"] || []).map { |a| a["name"] }.join(", ")
        )
      end
    end

  batch.new_releases.order(:position).map { |r| build_new_release_from_row(r) }
end

  def followed_artists(limit:, max_age: 4.days)
    spotify_user_id = session.dig(:spotify_user, "id")
    raise "Missing user id" if spotify_user_id.blank?

    batch = FollowedArtistBatch
              .where(spotify_user_id: spotify_user_id, limit: limit)
              .where("fetched_at >= ?", max_age.ago)
              .includes(:followed_artists)
              .first

    if batch.present?
      Rails.logger.info "[FollowedArtists] Cache HIT"
      return batch.followed_artists.order(:position).map { |row| build_followed_artist(row) }
    end

    Rails.logger.info "[FollowedArtists] Cache MISS → Fetching from Spotify"

    access_token = ensure_access_token!
    response = get("/me/following", access_token, limit: limit, type: "artist")
    items = response.dig("artists", "items") || []

    FollowedArtistBatch.transaction do
      batch ||= FollowedArtistBatch.create!(
        spotify_user_id: spotify_user_id,
        limit: limit,
        fetched_at: Time.current
      )

      batch.update!(fetched_at: Time.current)
      batch.followed_artists.delete_all

      items.each_with_index do |item, index|
        batch.followed_artists.create!(
          position:    index + 1,
          spotify_id:  item["id"],
          name:        item["name"],
          image_url:   item.dig("images", 0, "url"),
          genres:      item["genres"] || [],
          popularity:  item["popularity"],
          spotify_url: item.dig("external_urls", "spotify")
        )
      end
    end

    batch.followed_artists.order(:position).map { |row| build_followed_artist(row) }
  end

  def fetch_mood_features(spotify_track_ids)
    ReccoBeatsClient.fetch_audio_features(spotify_track_ids)
  end

  def top_tracks_1(limit: 10, time_range: "medium_term")
    access_token = ensure_access_token!
    response = get("/me/top/tracks", access_token, {
      limit: limit,
      time_range: time_range
    })

    items = response["items"] || []

    items.map do |t|
      OpenStruct.new(
        id: t["id"],
        name: t["name"],
        artists: t["artists"].map { |a| a["name"] }.join(", "),
        image: t.dig("album", "images", 0, "url")
      )
    end
  end

  def playlist_tracks(playlist_id:, limit: 100)
    access_token = ensure_access_token!
    collected = []
    offset = 0

    while collected.length < limit
      page_limit = [ 100, limit - collected.length ].min
      response = get("/playlists/#{playlist_id}/tracks", access_token, limit: page_limit, offset: offset)
      items = Array(response["items"])
      break if items.empty?

      items.each do |item|
        track = item["track"] || {}
        collected << OpenStruct.new(
          id: track["id"],
          name: track["name"],
          artists: (track["artists"] || []).map { |a| a["name"] }.join(", "),
          duration_ms: track["duration_ms"],
          spotify_url: track.dig("external_urls", "spotify")
        )
      end

      break if items.length < page_limit

      offset += page_limit
    end

    collected
  end

  def recently_played(limit:)
    limit = limit.to_i
    limit = 50 if limit <= 0
    limit = [ limit, 200 ].min

    cache_for([ "recently_played", limit, RECENTLY_PLAYED_CACHE_VERSION ], expires_in: 15.minutes) do
      access_token = ensure_access_token!
      collected = []
      before_cursor = nil
      seen = {}

      while collected.length < limit
        page_limit = [ 50, limit - collected.length ].min
        params = { limit: page_limit }
        params[:before] = before_cursor if before_cursor

        response = get("/me/player/recently-played", access_token, params)
        items = Array(response["items"])
        break if items.empty?

        items.each do |item|
          stamp = extract_before_cursor(item)
          next unless stamp

          dedupe_key = [ stamp, (item.dig("track", "id") || "unknown") ]
          next if seen[dedupe_key]

          seen[dedupe_key] = true
          collected << item
        end

        new_cursor = extract_before_cursor(items.last)

        # Stop paginating if there isn't a usable cursor or we got fewer than requested
        break if new_cursor.nil? || new_cursor == before_cursor || items.length < page_limit

        # Step back 1ms to avoid receiving the last item again
        before_cursor = new_cursor - 1
      end

      collected = collected.first(limit)

      collected.map do |item|
        track = item["track"] || {}
        OpenStruct.new(
          id: track["id"],
          name: track["name"],
          duration_ms: track["duration_ms"],
          album_name: track.dig("album", "name"),
          album_image_url: track.dig("album", "images", 0, "url"),
          artists: (track["artists"] || []).map { |a| a["name"] }.join(", "),
          preview_url: track["preview_url"],
          spotify_url: track.dig("external_urls", "spotify"),
          played_at: parse_played_at(item["played_at"])
        )
      end
    end
  end


  def top_artists(limit:, time_range:, max_age: 4.days)
    spotify_user_id = session.dig(:spotify_user, "id")

    raise "Missing user ID" if spotify_user_id.blank?

    batch = TopArtistBatch.find_by(
      spotify_user_id: spotify_user_id,
      time_range:      time_range,
      limit:           limit
    )

    if batch.present? && batch.fetched_at >= max_age.ago
      Rails.logger.info "[TopArtists] Cache HIT for #{spotify_user_id}, #{time_range}"
      return batch.top_artist_results
                  .order(:position)
                  .map { |row| build_top_artist_from_row(row) }
    end

    Rails.logger.info "[TopArtists] Cache MISS (fetching fresh data)"

    access_token = ensure_access_token!
    response = get("/me/top/artists", access_token, limit: limit, time_range: time_range)
    items = response.fetch("items", [])

    TopArtistBatch.transaction do
      batch ||= TopArtistBatch.create!(
        spotify_user_id: spotify_user_id,
        time_range:      time_range,
        limit:           limit,
        fetched_at:      Time.current
      )

      batch.update!(fetched_at: Time.current)
      batch.top_artist_results.delete_all

      items.each_with_index do |item, index|
        batch.top_artist_results.create!(
          position:   index + 1,
          spotify_id: item["id"],
          name:       item["name"],
          image_url:  item.dig("images", 0, "url"),
          genres:     (item["genres"] || []).join(", "),
          popularity: item["popularity"],
          playcount:  item["popularity"]
        )
      end
    end

    batch.top_artist_results.order(:position).map do |row|
      build_top_artist_from_row(row)
    end
  end

  def top_tracks(limit:, time_range:, max_age: 4.days)
    spotify_user_id = session.dig(:spotify_user, "id")
    raise "Missing user id in session" if spotify_user_id.blank?

    batch = TopTrackBatch.find_by(
      spotify_user_id: spotify_user_id,
      time_range:      time_range,
      limit:           limit
    )

    if batch.present? && batch.fetched_at >= max_age.ago
      Rails.logger.info "[TopTracks] Cache HIT for #{spotify_user_id}, #{time_range}"
      return batch.top_track_results
                  .order(:position)
                  .map { |row| build_top_track_from_row(row) }
    end

    Rails.logger.info "[TopTracks] Cache MISS (fetching from Spotify)"

    access_token = ensure_access_token!
    response = get("/me/top/tracks", access_token, limit: limit, time_range: time_range)
    items = response.fetch("items", [])

    TopTrackBatch.transaction do
      batch ||= TopTrackBatch.create!(
        spotify_user_id: spotify_user_id,
        time_range:      time_range,
        limit:           limit,
        fetched_at:      Time.current
      )

      batch.update!(fetched_at: Time.current)
      batch.top_track_results.delete_all

      items.each_with_index do |item, index|
        batch.top_track_results.create!(
          position:        index + 1,
          spotify_id:      item["id"],
          name:            item["name"],
          artists:         (item["artists"] || []).map { |a| a["name"] }.join(", "),
          album_name:      item.dig("album", "name"),
          album_image_url: item.dig("album", "images", 0, "url"),
          popularity:      item["popularity"],
          preview_url:     item["preview_url"],
          spotify_url:     item.dig("external_urls", "spotify"),
          duration_ms:     item["duration_ms"]
        )
      end
    end

    batch.top_track_results.order(:position).map do |row|
      build_top_track_from_row(row)
    end
  end

  def follow_artists(ids)
    ids = Array(ids).map(&:to_s).uniq
    return true if ids.empty?

    access_token = ensure_access_token!
    body = { ids: ids }
    request_with_json(Net::HTTP::Put, "/me/following", access_token, params: { type: "artist" }, body: body)
    true
  end

  def unfollow_artists(ids)
    ids = Array(ids).map(&:to_s).uniq
    return true if ids.empty?

    access_token = ensure_access_token!
    body = { ids: ids }
    request_with_json(Net::HTTP::Delete, "/me/following", access_token, params: { type: "artist" }, body: body)
    true
  end

  def followed_artist_ids(ids)
    ids = Array(ids).map(&:to_s).uniq
    return Set.new if ids.empty?

    access_token = ensure_access_token!
    result = Set.new

    ids.each_slice(50) do |chunk|
      response = get("/me/following/contains", access_token, type: "artist", ids: chunk.join(","))
      statuses = Array(response)
      chunk.each_with_index do |id, index|
        result << id if statuses[index]
      end
    end

    result
  end

  # Returns the Spotify account id of the current user (string).
  def current_user_id
    access_token = ensure_access_token!
    me = get("/me", access_token)
    uid = me["id"]
    uid = session.dig("spotify_user", "id")

    if uid.blank?
      access_token = ensure_access_token!
      me = get("/me", access_token)
      uid = me["id"]
    end

    raise Error, "Could not determine Spotify user id" if uid.blank?
    uid
  end

  # Create a new playlist in the given user's Spotify account.
  # Returns the new playlist's Spotify ID (string).
  def create_playlist_for(user_id:, name:, description:, public: false)
    access_token = ensure_access_token!

    payload = {
      name:        name,
      description: description,
      public:      public
    }

    response = post_json("/users/#{user_id}/playlists", access_token, payload)
    playlist_id = response["id"]

    if playlist_id.blank?
      raise Error, "Failed to create playlist"
    end

    playlist_id
  end

  # Add a set of track URIs to an existing playlist.
  # uris: array of strings like "spotify:track:123abc"
  def add_tracks_to_playlist(playlist_id:, uris:)
    access_token = ensure_access_token!

    payload = {
      uris: uris
    }

    post_json("/playlists/#{playlist_id}/tracks", access_token, payload)
    true
  end

  def clear_user_cache
    user_id = current_user_id
    return unless user_id

    TrackSearch.where(spotify_user_id: user_id).destroy_all
    TopArtistBatch.where(spotify_user_id: user_id).destroy_all
    TopTrackBatch.where(spotify_user_id: user_id).destroy_all
    FollowedArtistBatch.where(spotify_user_id: user_id).destroy_all
  end


  private

  attr_reader :session, :client_id, :client_secret

  private

  def build_track_from_row(row)
    OpenStruct.new(
      id:           row.spotify_id,
      name:         row.name,
      artists:      row.artists,
      album_name:   row.album_name,
      album_image_url: row.album_image_url,
      popularity:   row.popularity,
      preview_url:  row.preview_url,
      spotify_url:  row.spotify_url,
      duration_ms:  row.duration_ms
    )
  end

  private

  def build_top_artist_from_row(row)
    OpenStruct.new(
      id:         row.spotify_id,
      name:       row.name,
      rank:       row.position,
      image_url:  row.image_url,
      genres:     (row.genres || "").split(", "),
      popularity: row.popularity,
      playcount:  row.playcount
    )
  end

  private

  def build_followed_artist(row)
    OpenStruct.new(
      id:          row.spotify_id,
      name:        row.name,
      image_url:   row.image_url,
      genres:      row.genres,
      popularity:  row.popularity,
      spotify_url: row.spotify_url,
      rank:        row.position
    )
  end

  private

  def build_new_release_from_row(row)
    OpenStruct.new(
      id:           row.spotify_id,
      name:         row.name,
      image_url:    row.image_url,
      total_tracks: row.total_tracks || 0,
      release_date: row.release_date || "",
      spotify_url:  row.spotify_url,
      artists:      (row.artists || "").split(", ").reject(&:blank?)
    )
  end

  private

  def build_top_track_from_row(row)
    OpenStruct.new(
      id:              row.spotify_id,
      name:            row.name,
      rank:            row.position,
      artists:         row.artists,
      album_name:      row.album_name,
      album_image_url: row.album_image_url,
      popularity:      row.popularity,
      preview_url:     row.preview_url,
      spotify_url:     row.spotify_url,
      duration_ms:     row.duration_ms
    )
  end

  def cache_for(key_parts, expires_in: 24.hours)
    user_id = current_user_id
    return yield unless user_id # fallback if no user logged in

    # Build a stable cache key like "spotify_12345_top_tracks_medium_term_20"
    key = [ "spotify", user_id, *Array(key_parts) ].join("_")

    Rails.logger.info "[SpotifyCache] Looking for key: #{key}"   # Always prints
    result = Rails.cache.fetch(key, expires_in: expires_in) do
      Rails.logger.info "[SpotifyCache] Cache miss! Fetching from Spotify API for key: #{key}"
      yield
    end

    Rails.logger.info "[SpotifyCache] Cache hit! Key found: #{key}" if result
    result
  end

  def ensure_access_token!
    token = session[:spotify_token]
    return token if token.present? && !token_expired?

    refresh_access_token!
  end

  def token_expired?
    expires_at = session[:spotify_expires_at]
    return true unless expires_at

    Time.at(expires_at.to_i) <= Time.current + 30
  end

  def refresh_access_token!
    refresh_token = session[:spotify_refresh_token]
    raise UnauthorizedError, "Missing Spotify refresh token" if refresh_token.blank?
    raise UnauthorizedError, "Missing Spotify client credentials" if client_id.blank? || client_secret.blank?

    response = post_form(
      TOKEN_URI,
      {
        grant_type: "refresh_token",
        refresh_token: refresh_token
      },
      token_headers
    )

    unless response["access_token"]
      message = response["error_description"] || response.dig("error", "message") || "Unknown error refreshing token"
      raise UnauthorizedError, message
    end

    session[:spotify_token] = response["access_token"]
    session[:spotify_expires_at] = Time.current.to_i + response.fetch("expires_in", 3600).to_i
    session[:spotify_refresh_token] = response["refresh_token"] if response["refresh_token"].present?

    session[:spotify_token]
  end

  def get(path, access_token, params = {})
    uri = URI.parse("#{API_ROOT}#{path}")
    uri.query = URI.encode_www_form(params)

    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json"

    perform_request(uri, request)
  end

  def request_with_json(http_method_class, path, access_token, params: {}, body: nil)
    uri = URI.parse("#{API_ROOT}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?

    request = http_method_class.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"] = "application/json"
    request.body = body.nil? ? nil : JSON.dump(body)

    perform_request(uri, request)
  end

  def post_form(uri, params = {}, headers = {})
    request = Net::HTTP::Post.new(uri)
    request.set_form_data(params)
    headers.each { |key, value| request[key] = value }

    perform_request(uri, request)
  end

  def perform_request(uri, request)
  response = Net::HTTP.start(
    uri.host,
    uri.port,
    use_ssl: uri.scheme == "https",
    open_timeout: 5,
    read_timeout: 5,
    verify_mode: (Rails.env.development? ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER)
  ) do |http|
    http.request(request)
  end

  body = parse_json(response.body)

  if response.code.to_i >= 400
    message = body["error_description"] || body.dig("error", "message") || response.message
    raise Error, message
  end

  body
  rescue SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError => e
    Rails.logger.error "[SpotifyClient] network/SSL error: #{e.class}: #{e.message}"
    raise Error, e.message
  end

  def parse_json(payload)
    return {} if payload.nil? || payload.empty?

    JSON.parse(payload)
  rescue JSON::ParserError
    {}
  end

  def extract_before_cursor(item)
    return nil unless item

    timestamp = item["played_at"]
    parsed = parse_played_at(timestamp)
    return nil unless parsed

    (parsed.to_f * 1000).to_i
  rescue ArgumentError
    nil
  end

  def parse_played_at(value)
    return nil if value.blank?

    Time.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def token_headers
    encoded = Base64.strict_encode64("#{client_id}:#{client_secret}")
    {
      "Authorization" => "Basic #{encoded}",
      "Content-Type" => "application/x-www-form-urlencoded"
    }
  end

  # Build full Spotify track URIs that the playlist API expects
  def track_uris_from_tracks(tracks)
    tracks.map { |t| "spotify:track:#{t.id}" }
  end

  def post_json(path, access_token, body_hash)
    uri = URI.parse("#{API_ROOT}#{path}")

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{access_token}"
    request["Content-Type"]  = "application/json"
    request.body = JSON.dump(body_hash)

    perform_request(uri, request)
  end
end
