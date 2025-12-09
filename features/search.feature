Feature: Searching for Spotify Content
  As a logged-in user,
  I want to be able to search for artists, tracks, and albums
  So that I can find new music and view analytics.

  Background:
    Given I am signed in with Spotify

  Scenario: Handling Spotify Unauthorized Error (Session Expired)
    Given Spotify API responds to search with UnauthorizedError
    When I visit the search page with query "expired_token"
    Then I should be redirected to "/"

  Scenario: Handling Generic Spotify API Failure
    Given Spotify API responds to search with GenericError
    When I visit the search page with query "failing_api"
    Then I should not see any search results
    And the response status should be 200
    And the application should log an error