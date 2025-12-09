# spec/services/search_service_spec.rb
require 'rails_helper'

RSpec.describe SearchService do
  # Define a mock object for the external client (e.g., SpotifyClient)
  # This double is used to ensure the SearchService interacts with it correctly.
  let(:mock_client) { instance_double('ExternalClient') }

  # The service instance we are testing
  subject(:service) { described_class.new(client: mock_client) }

  describe '#perform' do
    let(:valid_query) { 'The Beatles' }
    let(:empty_result) { { tracks: [], artists: [], playlists: [] } }
    let(:search_result) do
      {
        tracks:    [ 'Song A', 'Song B' ],
        artists:   [ 'Artist X' ],
        playlists: [ 'Playlist Z' ]
      }
    end

    context 'when the query is blank or nil' do
      it 'returns an empty hash structure for a blank string' do
        expect(service.perform('')).to eq(empty_result)
      end

      it 'returns an empty hash structure for nil' do
        expect(service.perform(nil)).to eq(empty_result)
      end

      it 'does NOT call the client search method' do
        # We ensure that the dependency is never invoked when the input is invalid
        expect(mock_client).not_to receive(:search_all)
        service.perform(' ') # Test with a string containing only whitespace
      end
    end

    context 'when the query is present' do
      it 'calls search_all on the client with the correct query' do
        # We expect the client's method to be called exactly once with the valid query
        expect(mock_client).to receive(:search_all).once.with(valid_query).and_return(search_result)

        service.perform(valid_query)
      end

      it 'returns the result received from the client' do
        # Stub the client call to return our mock result
        allow(mock_client).to receive(:search_all).and_return(search_result)

        result = service.perform(valid_query)

        # Verify that the service just passes the result straight through
        expect(result).to eq(search_result)
      end
    end
  end
end
