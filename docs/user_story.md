# Spotilytics User Stories

## Total Story points: 53

## Sprint 1

---

### **1. Store User’s Top Tracks and Artists in a Database**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/1

**User Story:**  
As a logged-in Spotify user, I want the app to store my top tracks and top artists in a local database, so the dashboard loads faster without repeatedly calling Spotify’s API.

**Acceptance Criteria:**

- The system fetches the user’s top tracks and artists from Spotify and stores them with timestamps.
- Dashboard loads cached database records unless data is stale.
- Data refreshes only when:
  - The user clicks “Refresh Data”, or
  - Stored data is older than 4 days.

---

### **2. Hour-of-Day Listening Pattern**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/7

**User Story:**  
As a user, I want a histogram showing which hours of the day I listen to music most, so I can understand my habits.

---

### **3. Refresh User Data on Demand or Weekly Scheduler**

**Points:** 2  
**Issue:** https://githubgithub.com/tamu-edu-students/Spotilytics-project3-team2/issues/4

**User Story:**  
As a user, I want a “Refresh Data” button to manually refresh top tracks and artists, and I want the app to auto-refresh if I don’t manually.

**Acceptance Criteria:**

- A “Refresh Data” button appears for logged-in users.
- Clicking it fetches latest top tracks and artists.
- Dashboard updates and shows a success message.
- The system stores `last_refreshed_at` and uses cached data unless older than 7 days.
- A background scheduler refreshes data every 4 days.

---

### **4. Track Journey: How My Taste Changed Over Time**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/11

**User Story:**  
As a returning Spotify user, I want to see how my top tracks evolve across multiple periods, so I can understand how my taste shifts.

**Acceptance Criteria:**

- Retrieves top tracks for 4 weeks, 6 months, and 1 year.
- Categorizes tracks into:
  - Evergreen: appears in all three
  - New Obsession: appears only in 4-week
  - Short-Term Crush: appears in 4-week and 6-month
  - Fading Out: ranking drops over time
- Track cards show: name, artists, album image, rankings.
- Empty categories show a placeholder message.

---

### **5. Global Search Feature (Spotify Search API)**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/3

**User Story:**  
As a user, I want to search for songs, artists, or albums via Spotify’s Search API so I can quickly find music.

---

### **6. Listening Habit Calendar**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/12

**User Story:**  
As a user, I want a calendar heatmap of my listening activity (using recently played timestamps), similar to GitHub commits.

---

### **7. Playlist Split by Genre**

**Points:** 5
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/5

**User Story:**
As a Spotify user, I want to split a playlist into new playlists by genre so I can organize music based on moods or themes.

**Acceptance Criteria:**

* User clicks **“Split by Genre”** on the genre breakdown page.
* System creates new playlists on Spotify:

  * One playlist per genre containing matching tracks.
* User sees confirmation + list of generated playlists.
* If playlist has no genres, show an error.

----

## Sprint 2

---

### **7. Interactive Mood Explorer Dashboard (JS Mode)**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/9

**User Story:**  
As a Spotify user, I want an interactive mood dashboard with real-time filtering and dynamic charts.

**Acceptance Criteria:**

- Dashboard loads user’s top tracks and audio features via ReccoBeats API.
- Mood wheel appears only when JavaScript is enabled.
- Clicking a mood filters tracks; clicking again resets.

**Micro-Analysis Panel:**  
When a track is selected, update dynamically:

- Track name and artist
- Mood tags
- Feature values
- Radar chart (5 attributes)

---

### **8. AI-Style “Music Personality” Summary**

**Points:** 2  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/10

**User Story:**  
As a user, I want a fun personality description derived from audio features (rule-based, no AI required).

---

### **9. Playlist Energy Curve Renderer**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/14

**User Story:**  
As a user, I want to see an energy graph across a playlist to understand pacing.

**Acceptance Criteria :**
Scenario: Viewing the playlist energy graph  
Given the playlist energy service returns sample points  
When I visit “/playlists/pl123/energy”  
Then I should see “Energy Rollercoaster”  
And I should see “Playlist ID: pl123”  
And I should see “Track Alpha”  
And I should see “Track Beta”  
And I should see “Energy by track”  
And I should see “75.0%”

---

### **10. Long-Term Trendline of Streaming Hours**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/8

**User Story:**  
As a user, I want to see how many hours I listen each month to track long-term trends.

**Acceptance Criteria:**  
Scenario: Viewing monthly listening chart with previous month summary  
Given Spotify returns recent plays across two months  
When I visit “/listening-monthly”  
Then I should see “Hours you’ve spent by month”  
And I should see “Previous month”  
And I should see “Jan 2025”  
And I should see “Dec 2024”

---

### **11. Mood Explorer Static Dashboard (No-JS Mode)**

**Points:** 2  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/21

**User Story:**  
As a user without JavaScript, I want a static fallback mood dashboard.

**Acceptance Criteria:**

- Interactive mood wheel and radar chart do not render.
- A static Mood Navigator explains that interactive features require JS.
- Each track card includes a “View Mood Analysis” link.
- The mood analysis page shows:
  - Track name, artist, album image
  - Audio feature values
  - Derived mood cluster

---

### **12. Interactive Track-Level Audio Features Panel (JS Mode)**

**Points:** 1  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/25

**User Story:**  
As a Spotify user, I want a micro-analysis panel for detailed track-level features.

**Acceptance Criteria:**  
Selecting a track updates:

- Track name and artist
- Mood tags
- Feature values
- Radar chart (5 attributes)

---

### **13. Compare My Playlist With a Friend (Overlap Track)**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/13

**User Story:**  
As a user, I want to compare my playlist with a friend’s to see overlap and a compatibility score, plus an explanation of why they match.

**Acceptance Criteria:**  
Scenario: Viewing compatibility with overlap  
Given Spotify playlists A and B return tracks with overlap  
And ReccoBeats returns feature vectors for playlists A and B  
When I visit “/playlists/compare?source_id=plA&target_id=plB”  
Then I should see “Playlist Compatibility”  
And I should see “Playlist A: plA”  
And I should see “Playlist B: plB”  
And I should see “Common tracks: 2”  
And I should see “Compatibility”  
And I should see “100%”  
And I should see “Why these playlists vibe”

---

### **14. Storing of Listening History**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/29

**User Story:**  
As a user I would like the ability to see past listening history aside from the most recent 50 that Spotify can provide to me.

---

### **15. Ability to Choose Number of Songs in Listening Hours**

**Points:** 1  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/32

**User Story:**  
As a user I would like the ability to choose the number of songs in my history for listening patterns.

---

### **16. Recent Plays on Listening History**

**Points:** 1  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/33

**User Story:**  
As a user I would like the ability to see the most recent songs that I have listened to on my hourly listening history page.

---

### **17. Compare My Playlist With a Friend — Compatibility Score**

**Points:** 4  
**Issue:**  
https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/34

**User Story:**  
As a user, I want to see a compatibility score between two playlists based on audio features, so I can understand how similar they feel even if we don’t share many tracks.

**Acceptance Criteria:**  
Scenario: Viewing compatibility with overlap  
Given Spotify playlists A and B return tracks with overlap  
And ReccoBeats returns feature vectors for playlists A and B  
When I visit “/playlists/compare?source_id=plA&target_id=plB”  
Then I should see “Playlist Compatibility”  
And I should see “Playlist A: plA”  
And I should see “Playlist B: plB”  
And I should see “Common tracks: 2”  
And I should see “Compatibility”  
And I should see “100%”  
And I should see “Why these playlists vibe”

---

### **18. Sort/Split Spotify Playlist by Genre**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/5

**User Story:**  
As a user, I want to sort or split any playlist by genre, so I can understand its composition and mood distribution.

⸻

### **19. Wrapped-Style Story Viewer**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/6

**User Story:**  
As a user, I want a wrapped-style story viewer that summarizes my music habits in a slideshow format.

⸻

### **20. Share a Playlist as a List of Spotify Links With a Friend**

**Points:** 3  
**Issue:** https://github.com/tamu-edu-students/Spotilytics-project3-team2/issues/2

**User Story:**  
As a user, I want to generate a clean list of Spotify track links from a playlist, so I can share it easily with friends.
