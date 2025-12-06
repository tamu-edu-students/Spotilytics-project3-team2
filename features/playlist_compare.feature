Feature: Playlist compatibility
  As a listener
  I want to compare playlists
  So I can see overlap and compatibility

  Background:
    Given OmniAuth is in test mode
    And I am signed in with Spotify

  Scenario: Viewing compatibility with overlap
    Given Spotify playlists A and B return tracks with overlap
    And ReccoBeats returns feature vectors for playlists A and B
    When I visit "/playlists/compare?source_id=plA&target_id=plB"
    Then I should see "Playlist Compatibility"
    And I should see "Playlist A: plA"
    And I should see "Playlist B: plB"
    And I should see "Common tracks: 2"
    And I should see "Compatibility"
    And I should see "100%"
    And I should see "Why these playlists vibe"

  Scenario: Not enough audio data
    Given Spotify playlists A and B return tracks with overlap
    And ReccoBeats returns empty features
    When I visit "/playlists/compare?source_id=plA&target_id=plB"
    Then I should see "Not enough audio data"
    And I should see "Common tracks: 2"
