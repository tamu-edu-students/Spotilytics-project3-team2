# Assuming SpotifyClient is already required and available

# Helper for mocking the SpotifyClient instance
def mock_spotify_client
  @mock_client ||= instance_double(SpotifyClient).tap do |client|
    allow(SpotifyClient).to receive(:new).and_return(client)
  end
end

def mock_spotify_result(type, index)
  base = {
    "id"            => "#{type[0]}#{index}",
    "name"          => "#{type.capitalize} Name #{index}",
    "external_urls" => { "spotify" => "http://example.com/#{type}/#{index}" },
    # All result types require an image nested inside an array of hashes
    "images"        => [ { "url" => "http://example.com/img#{index}.jpg" } ]
  }

  case type
  when :tracks
    # Tracks require 'artists' array and 'album' with nested 'images'
    base["artists"] = [ { "name" => "Mock Track Artist #{index}" } ]
    base["album"]   = { "images" => base["images"] }
    base.delete("images") # Tracks use album images, not direct images
    base
  when :artists
    # Artists require 'images' array
    base
  when :albums
    # Albums require 'images' array AND 'artists' array
    base["artists"] = [ { "name" => "Mock Album Artist #{index}" } ]
    base
  end
end


# --- Given Steps ---
Given(/^Spotify API responds to search with success and data$/) do |table|
  results = {}
  table.hashes.each do |row|
    type = row.keys.first.to_sym
    count = row.values.first.to_i

    results[type] = Array.new(count) do |i|
      # FIX: Use the universal helper for all result types
      mock_spotify_result(type, i)
    end
  end
  allow(mock_spotify_client).to receive(:search).and_return(results)
end

Given(/^Spotify API responds to search with UnauthorizedError$/) do
  allow(mock_spotify_client).to receive(:search).and_raise(SpotifyClient::UnauthorizedError.new("token expired"))
end

Given(/^Spotify API responds to search with GenericError$/) do
  # Mock Rails.logger to confirm the error is caught
  allow(Rails.logger).to receive(:error)
  allow(mock_spotify_client).to receive(:search).and_raise(StandardError.new("Network Timeout"))
end

Given(/^the application knows the login path is "([^"]*)"$/) do |path|
  # Mocking the route helper used in the controller's redirect
  allow_any_instance_of(SearchController).to receive(:login_path).and_return(path)
end

# --- When Steps ---

When(/^I visit the search page with query "([^"]*)"$/) do |query|
  # Use the literal path and pass the query parameter (using 'query' param)
  visit "/search?query=#{query}"
end

When(/^I visit the search page$/) do
  # Visit without a query
  visit "/search"
end

# --- Then Steps ---

Then(/^I should see a list of (\d+) artists$/) do |count|
  # Scope the search to the "Artists" section, then count the card titles (h5)
  # within the subsequent row div.
  within("h2", text: "Artists") do
    # Capybara finds the next containing element after the h2, which is the row div.
    # We use all('.card-title') to count the rendered results.
    artist_cards = page.all('.card-title')
    expect(artist_cards.size).to eq(count.to_i)
  end
end

Then(/^I should see a list of (\d+) tracks$/) do |count|
  # Scope the search to the "Tracks" section.
  within("h2", text: "Tracks") do
    track_cards = page.all('.card-title')
    expect(track_cards.size).to eq(count.to_i)
  end
end

Then(/^I should see a list of (\d+) albums$/) do |count|
  # Scope the search to the "Albums" section.
  within("h2", text: "Albums") do
    album_cards = page.all('.card-title')
    expect(album_cards.size).to eq(count.to_i)
  end
end

Then(/^I should not see any search results$/) do
  # Check that none of the result containers are present
  expect(page).to_not have_selector('.search-result')
end

Then(/^the application should log an error$/) do
  expect(Rails.logger).to have_received(:error)
end

Given('I am logged in with Spotify') do
  # This step sets up the session to mimic a successful Spotify login.
  # We need to ensure the session contains the required user data for
  # the controller's `before_action :require_spotify_auth!` to pass.

  # NOTE: If your application uses a Spotify token, include that here as well.

  spotify_user_data = {
    "id" => "test-cucumber-user",
    "display_name" => "Cucumber Test User",
    "email" => "test@example.com"
  }

  # For RSpec/Capybara integration, you often need to set session variables
  # directly in the controller context or rely on a custom test helper
  # (e.g., 'Devise::Test::IntegrationHelpers' style).
  # Assuming you have a helper function to set session keys:
  if defined?(set_session_for_feature)
    set_session_for_feature(:spotify_user, spotify_user_data)
  else
    # Fallback/alternative if your framework allows direct session manipulation
    page.set_rack_session(spotify_user: spotify_user_data)
  end
end


# --- Web Assertion Steps ---

Then('the response status should be {int}') do |expected_status|
  # Checks the HTTP response status code of the last request.
  # Capybara uses page.status_code, but if redirects happen,
  # we check the last response's status.

  # Use response.status if testing directly with Rack::Test/ActionDispatch::IntegrationTest
  # within the Cucumber steps.
  if respond_to?(:response) && response
    expect(response.status).to eq(expected_status)
  else
    # Fallback for Capybara browser tests (often 200 after redirects)
    expect(page.status_code).to eq(expected_status)
  end
end

Then('I should be redirected to {string}') do |expected_path|
  # Checks if the browser's current path matches the expected redirection path.
  expect(current_path).to eq(expected_path)
end

Then('I should see the alert message {string}') do |expected_message|
  # Checks for the presence of the flash alert message.
  # This assumes your Rails layout renders flash messages inside a container
  # with a class like `.alert` or `.flash`.

  # Check common locations for flash messages:
  expect(page).to have_content(expected_message)

  # Optional: Check if it's styled as an alert/flash if your app has specific selectors
  # expect(page).to have_selector('.alert', text: expected_message)
end
