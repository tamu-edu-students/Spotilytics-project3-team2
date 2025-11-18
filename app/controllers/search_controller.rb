class SearchController < ApplicationController
  def index
    return unless params[:query].present?

    @artists = RSpotify::Artist.search(params[:query])
    @tracks  = RSpotify::Track.search(params[:query])
    @albums  = RSpotify::Album.search(params[:query])
  rescue => e
    Rails.logger.error("Spotify Search Error: #{e.message}")
    @artists = []
    @tracks  = []
    @albums  = []
  end
end
