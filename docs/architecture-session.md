# Session Flow Diagram

```mermaid
flowchart LR
  subgraph Browser["User Browser"]
    Cookie["Session Cookie (encrypted)"]
  end

  subgraph Rails["Rails Server"]
    Session["session[:spotify_user]<br/>{ id, display_name, token, refresh_token, expires_at }"]
    Pages["Controllers<br/>(Pages / TopTracks / Playlists / ListeningPatterns / Personality)"]
    Client["SpotifyClient"]
    History["ListeningHistory"]
    Persona["MusicPersonality"]
    CacheAPI["Rails.cache (redis_cache_store)"]
    DB["DB (listening_plays, batches)"]
  end

  subgraph Infra["Heroku Add-on"]
    Redis["Redis<br/>namespace: spotilytics-cache<br/>TTL: 24h"]
  end

  subgraph Spotify["Spotify Platform"]
    OAuth["Accounts (OAuth2)"]
    API["Web API"]
  end

  %% Session lifecycle
  Cookie <--> Session
  Pages --> Client
  Pages --> History
  Pages --> Persona

  %% OAuth login
  Pages -->|Start OAuth| OAuth
  OAuth -->|Return tokens| Pages
  Pages -->|Save tokens in session| Session

  %% Token refresh inside client
  Client -->|Ensure access token| Session
  Client -->|Refresh token if expired| OAuth

  %% Cache check before API
  Client -->|Lookup cache key| CacheAPI
  CacheAPI <--> Redis
  History --> DB
  Pages -->|ActiveRecord| DB

  %% Cache hit / miss flow
  CacheAPI -- "Cache hit → Return cached data" --> Client
  CacheAPI -- "Cache miss → Fetch from Spotify API" --> Client
  Client -- "GET / POST" --> API
  Client -- "Store API result" --> CacheAPI
