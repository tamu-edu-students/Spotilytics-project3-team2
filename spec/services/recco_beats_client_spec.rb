require "rails_helper"

RSpec.describe ReccoBeatsClient do
  subject { described_class }

  describe ".fetch_audio_features" do
    it "returns [] when ids are blank" do
      expect(described_class.fetch_audio_features([])).to eq([])
    end

    it "parses content and adds spotify_id derived from href" do
      fake_body = {
        "content" => [
          {
            "id"          => "abc",
            "href"        => "https://open.spotify.com/track/track123",
            "energy"      => 0.9,
            "valence"     => 0.7,
            "danceability"=> 0.8
          }
        ]
      }.to_json

      fake_response = instance_double(Net::HTTPOK, is_a?: true, body: fake_body, code: "200")
      fake_http = instance_double(Net::HTTP)
      allow(fake_http).to receive(:get).and_return(fake_response)
      allow(described_class).to receive(:with_http).and_yield(fake_http)

      result = described_class.fetch_audio_features([ "track123" ])
      expect(result.size).to eq(1)
      expect(result.first["spotify_id"]).to eq("track123")
      expect(result.first["energy"]).to eq(0.9)
    end

    it "logs and returns [] on non-success" do
      fake_response = instance_double(Net::HTTPBadRequest, is_a?: false, body: "error", code: "400")
      fake_http = instance_double(Net::HTTP)
      allow(fake_http).to receive(:get).and_return(fake_response)
      allow(described_class).to receive(:with_http).and_yield(fake_http)

      expect(Rails.logger).to receive(:error).with(/ReccoBeats/)
      expect(described_class.fetch_audio_features([ "x" ])).to eq([])
    end
  end

  describe ".fetch_audio_features" do
    let(:track_ids) { [ "some-spotify-id" ] }

    context "when an exception is raised while calling the API" do
      before do
        fake_http = instance_double(Net::HTTP)
        allow(fake_http).to receive(:get).and_raise(RuntimeError, "boom")
        allow(described_class).to receive(:with_http).and_yield(fake_http)
      end

      it "logs the exception and returns an empty array" do
        expect(Rails.logger).to receive(:error)
          .with("[ReccoBeats] Batch exception: RuntimeError - boom")

        result = described_class.fetch_audio_features(track_ids)

        expect(result).to eq([])
      end
    end
  end

  describe 'private HTTP/SSL configuration methods' do
    # Define a generic URL for testing the connection setup
    let(:test_url) { URI("https://api.test.com") }

    describe '.ssl_verify_mode' do
      it 'returns OpenSSL::SSL::VERIFY_PEER when RECCOBEATS_DISABLE_SSL_VERIFY is not set' do
        # Ensure the environment variable is nil for this context
        allow(ENV).to receive(:[]).with("RECCOBEATS_DISABLE_SSL_VERIFY").and_return(nil)

        mode = subject.send(:ssl_verify_mode)
        expect(mode).to eq(OpenSSL::SSL::VERIFY_PEER)
      end

      it 'returns OpenSSL::SSL::VERIFY_NONE when RECCOBEATS_DISABLE_SSL_VERIFY is "true"' do
        # Mock the environment variable check
        allow(ENV).to receive(:[]).with("RECCOBEATS_DISABLE_SSL_VERIFY").and_return("true")

        mode = subject.send(:ssl_verify_mode)
        expect(mode).to eq(OpenSSL::SSL::VERIFY_NONE)
      end
    end

    describe '.build_cert_store' do
      let(:mock_store) { instance_double(OpenSSL::X509::Store) }
      let(:ca_path) { '/tmp/test_ca.pem' }

      before do
        allow(OpenSSL::X509::Store).to receive(:new).and_return(mock_store)
        allow(mock_store).to receive(:set_default_paths)
        allow(mock_store).to receive(:add_file)
        # Default assumption: CA file doesn't exist or is not set
        allow(ENV).to receive(:[]).with("RECCOBEATS_CA_FILE").and_return(nil)
        allow(File).to receive(:exist?).and_return(false)
      end

      it 'initializes a store and sets default paths' do
        subject.send(:build_cert_store)
        expect(mock_store).to have_received(:set_default_paths).once
      end

      context 'when RECCOBEATS_CA_FILE is set and exists' do
        before do
          allow(ENV).to receive(:[]).with("RECCOBEATS_CA_FILE").and_return(ca_path)
          allow(File).to receive(:exist?).with(ca_path).and_return(true)
        end

        it 'adds the custom CA file to the store' do
          subject.send(:build_cert_store)
          expect(mock_store).to have_received(:add_file).with(ca_path).once
        end
      end

      context 'when RECCOBEATS_CA_FILE is set but does not exist' do
        before do
          allow(ENV).to receive(:[]).with("RECCOBEATS_CA_FILE").and_return(ca_path)
          allow(File).to receive(:exist?).with(ca_path).and_return(false)
        end

        it 'does not add the custom CA file' do
          subject.send(:build_cert_store)
          expect(mock_store).not_to have_received(:add_file)
        end
      end
    end

    describe '.with_http' do
      let(:mock_http) { instance_double(Net::HTTP) }
      let(:mock_store) { instance_double(OpenSSL::X509::Store) }

      before do
        # Stub the initialization of Net::HTTP
        allow(Net::HTTP).to receive(:new).with(test_url.host, test_url.port).and_return(mock_http)

        # Stub dependent methods
        allow(subject).to receive(:ssl_verify_mode).and_return(OpenSSL::SSL::VERIFY_PEER)
        allow(subject).to receive(:build_cert_store).and_return(mock_store)

        # Expect configuration calls on the mock HTTP object
        expect(mock_http).to receive(:use_ssl=).with(true)
        expect(mock_http).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
        expect(mock_http).to receive(:cert_store=).with(mock_store)
      end

      it 'configures the HTTP object and yields it to the block' do
        # Check that the block is yielded to and receives the mock_http object
        expect { |b| subject.send(:with_http, test_url, &b) }.to yield_with_args(mock_http)
      end
    end
  end
end
