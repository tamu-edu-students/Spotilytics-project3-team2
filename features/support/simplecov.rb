# Start SimpleCov before anything else is loaded
require 'simplecov'

SimpleCov.command_name 'Cucumber'
SimpleCov.coverage_dir 'coverage/cucumber'

SimpleCov.start 'rails' do
  enable_coverage :branch
  add_filter %w[/spec/ /config/ /vendor/ /db/ /test/ /helpers/ /models/ /services/search_service.rb /services/recco_beats_client.rb /services/playlist_vector_service.rb /services/track_journey.rb]
  add_group 'Controllers', 'app/controllers'
end
