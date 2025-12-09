Feature: Playlist Genre Analysis
  As a logged-in user,
  I want to see my list of playlists and the genre breakdown for a selected playlist,
  So that I can understand the musical composition of my library.

  Background:
    Given I am signed in with Spotify
    And the application knows the login path is "/"

  # =======================================================
  # SCENARIO 1: INDEX Action (Listing Playlists)
  # =======================================================
  Scenario: Successfully listing user playlists
    Given Spotify API returns 3 user playlists
    When I visit the playlist genres index page
    Then the response status should be 200

  # =======================================================
  # SCENARIO 2: SHOW Action (Calculating Genre Breakdown)
  # =======================================================
  Scenario: Displaying the correct genre breakdown for a playlist
    Given Spotify API returns tracks and genres for playlist "rock-mix-id"
      | track_id | genres                                |
      | t1       | rock, alternative rock                |
      | t2       | alternative rock, indie rock          |
      | t3       | rock                                  |
    When I visit the playlist genre analysis page for "rock-mix-id"
    Then the response status should be 200
    And I should see the following genre breakdown:
      | Genre              | Count | Percentage |
      | rock               | 2     | 40.0%      |
      | alternative rock   | 2     | 40.0%      |
      | indie rock         | 1     | 20.0%      |