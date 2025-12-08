class PlaylistGenresController < ApplicationController
  before_action :require_spotify_auth!

  def index
    @playlists = spotify_client.user_playlists(limit: 50)
  end

  def show
    playlist_id = params[:id]

    tracks = spotify_client.playlist_tracks_with_genres(playlist_id)

    genre_counts = Hash.new(0)

    tracks.each do |t|
      Array(t[:genres]).each { |g| genre_counts[g] += 1 }
    end
    playlist = spotify_client.get_playlist(params[:id])
    @playlist_url = playlist.dig("external_urls", "spotify")

    total_genres = genre_counts.values.sum
    @share_url = playlist_genres_url(id: playlist_id)

    @genre_breakdown =
      genre_counts.map do |genre, count|
        percentage = ((count.to_f / total_genres) * 100).round(1)
        { genre: genre, count: count, percentage: percentage }
      end.sort_by { |g| -g[:count] }

    @top_genre = @genre_breakdown.first&.dig(:genre)
  end

  private

  def spotify_client
    @spotify_client ||= SpotifyClient.new(session: session)
  end
end
