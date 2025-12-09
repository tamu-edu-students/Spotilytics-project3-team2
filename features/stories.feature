Feature: Viewing Spotify Story (Playlist Details)
  As a logged-in user,
  I want to view details for a specific playlist ID,
  So that I can see the tracks and eventual analysis (story).

  Background:
    Given I am signed in with Spotify
    And the application knows the login path is "/"

  Scenario: Successfully loading tracks for a valid Playlist ID
    Given Spotify API successfully returns 10 tracks for playlist "mock-playlist-id-123"
    When I visit the story page for playlist "mock-playlist-id-123"
    Then the response status should be 200
    And I should see 10 tracks assigned to the view
