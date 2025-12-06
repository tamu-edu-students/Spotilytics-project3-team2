require "ostruct"

Given("Spotify playlists A and B return tracks with overlap") do
  tracks_a = [
    OpenStruct.new(id: "1", name: "One", artists: "A"),
    OpenStruct.new(id: "2", name: "Two", artists: "B"),
    OpenStruct.new(id: "3", name: "Three", artists: "C")
  ]
  tracks_b = [
    OpenStruct.new(id: "2", name: "Two", artists: "B"),
    OpenStruct.new(id: "3", name: "Three", artists: "C"),
    OpenStruct.new(id: "4", name: "Four", artists: "D")
  ]

  client = instance_double(SpotifyClient)
  allow(SpotifyClient).to receive(:new).with(session: anything).and_return(client)

  allow(client).to receive(:playlist_tracks).with(playlist_id: "plA", limit: 200).and_return(tracks_a)
  allow(client).to receive(:playlist_tracks).with(playlist_id: "plB", limit: 200).and_return(tracks_b)
end

Given("ReccoBeats returns feature vectors for playlists A and B") do
  vector_service = instance_double(PlaylistVectorService)
  allow(PlaylistVectorService).to receive(:new).and_return(vector_service)

  allow(vector_service).to receive(:build_vector).and_return(
    { vector: [ 1, 0, 0, 0, 0 ], valid_count: 5, total_tracks: 3 },
    { vector: [ 1, 0, 0, 0, 0 ], valid_count: 5, total_tracks: 3 }
  )
end

Given("ReccoBeats returns empty features") do
  vector_service = instance_double(PlaylistVectorService)
  allow(PlaylistVectorService).to receive(:new).and_return(vector_service)

  allow(vector_service).to receive(:build_vector).and_return(
    { vector: nil, valid_count: 0, total_tracks: 3 },
    { vector: nil, valid_count: 0, total_tracks: 3 }
  )
end
