class SearchService
  def initialize(client:)
    @client = client
  end

  def perform(query)
    return { tracks: [], artists: [], playlists: [] } if query.blank?

    client.search_all(query)
  end

  private

  attr_reader :client
end
