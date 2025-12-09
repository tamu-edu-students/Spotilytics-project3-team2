Feature: Spotify Wrapped Story Generation
  As a logged-in user,
  I want to view my personalized "Wrapped" story based on my top Spotify data,
  So that I can see a summary of my annual listening habits.

  Background:
    Given I am signed in with Spotify
    And the application knows the login path is "/"

  # =======================================================
  # SCENARIO 1: Full Data Successful Generation
  # =======================================================
  Scenario: Successfully generating the full story with all data
    Given Spotify API returns top track "Hit Song" with image "track-img-url" and genres "pop"
    And Spotify API returns top artist "Top Artist" with image "artist-img-url"
    When I visit the wrapped page
    Then the response status should be 200
    And the slide titled "Your Spotilytics Wrapped" should exist
    And the slide titled "Your Favorite Genre" should not exist

  # =======================================================
  # SCENARIO 2: Partial Data Handling (Missing Top Artist)
  # =======================================================
  Scenario: Successfully generating story when only top tracks are available
    Given Spotify API returns top track "Hit Song" with image "track-img-url" and genres "pop"
    And Spotify API returns no top artists
    When I visit the wrapped page
    Then the response status should be 200
    And the slide titled "Your Spotilytics Wrapped" should exist
    And the slide titled "Your Favorite Genre" should not exist

  # =======================================================
  # SCENARIO 3: No Data Available Fallback
  # =======================================================
  Scenario: Displaying fallback slide when no data is available
    Given Spotify API returns no top tracks
    And Spotify API returns no top artists
    When I visit the wrapped page
    Then the response status should be 200
    And the slide titled "No data to display" should exist

  # =======================================================
  # SCENARIO 4: Authentication Error Handling
  # =======================================================
  Scenario: Handling Unauthorized Error when fetching top data
    Given Spotify API raises UnauthorizedError when fetching top tracks
    When I visit the wrapped page
    Then I should be redirected to "/wrapped"
