class WrappedController < ApplicationController
  before_action :require_spotify_auth!

  def index
    client = SpotifyClient.new(session: session)

    # Fetch top tracks & artists
    tracks  = client.top_tracks(limit: 10, time_range: "long_term") rescue []
    artists = client.top_artists(limit: 5, time_range: "long_term") rescue []

    top_track  = tracks.first
    top_artist = artists.first

    # Build story slides
    @slides = []

    # Slide 1 — Welcome
    @slides << {
      title: "Your Spotilytics Wrapped",
      subtitle: "See your year in music",
      image: nil,
      type: :empty
    }

    # Slide 2 — Top Track
    if top_track
      @slides << {
        title: "Your #1 Song",
        subtitle: top_track.name,
        image: top_track.album_image_url,
        type: :track,
        extras: {
          popularity: top_track.popularity,
          preview_url: top_track.preview_url,
          spotify_url: top_track.spotify_url
        }
      }
    end

    # Slide 3 — Top Artist
    if top_artist
      @slides << {
        title: "Your Top Artist",
        subtitle: top_artist.name,
        image: top_artist.image_url,
        type: :artist,
        body: "You listened to them a lot this year!"
      }
    end

    # Slide 4 — Favorite Genre (from top artist)
    genre = top_artist&.genres&.first
    if genre.present?
      @slides << {
        title: "Your Favorite Genre",
        subtitle: genre.capitalize,
        image: nil,
        type: :genres,
        body: "This genre dominated your listening."
      }
    end

    # Ensure at least one slide
    @slides = [ { title: "No data available", type: :empty } ] if @slides.empty?
  end
end
