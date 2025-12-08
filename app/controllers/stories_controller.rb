class StoriesController < ApplicationController
  before_action :require_spotify_auth!

  def show
    client = SpotifyClient.new(session: session)

    @playlist_id = params[:playlist_id]
    @tracks = client.playlist_tracks(playlist_id: @playlist_id, limit: 100)

    # Later:
    # - audio features
    # - top genres
    # - top artists
    # - mood vectors
    # - slide rendering logic
  end
end
