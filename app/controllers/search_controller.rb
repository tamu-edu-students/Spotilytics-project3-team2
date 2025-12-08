class SearchController < ApplicationController
  before_action :require_spotify_auth!, only: %i[index]

  def index
    # accept either `query` or `q` in case some code still uses q
    query = (params[:query].presence || params[:q].presence || "").to_s.strip
    return unless query.present?

    begin
      results = spotify_client.search(query)
      # spotify_client.search returns a hash like { artists: [...], tracks: [...], albums: [...] }
      @artists = Array(results[:artists] || results["artists"] || [])
      @tracks  = Array(results[:tracks]  || results["tracks"]  || [])
      @albums  = Array(results[:albums]  || results["albums"]  || [])

      # Keep a combined object for older views that expect @results
      @results = { artists: @artists, tracks: @tracks, albums: @albums }
    rescue SpotifyClient::UnauthorizedError => e
      Rails.logger.warn "Spotify auth error in search: #{e.message}"
      redirect_to login_path, alert: "Spotify session expired. Please sign in again."
    rescue => e
      Rails.logger.error "Spotify search failed: #{e.class}: #{e.message}"
      @artists = @tracks = @albums = []
      @results = { artists: [], tracks: [], albums: [] }
    end
  end

  private

  def spotify_client
    @spotify_client ||= SpotifyClient.new(session: session)
  end
end
