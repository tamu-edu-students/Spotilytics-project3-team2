# System Architecture Diagram

```mermaid
graph TD
  subgraph User_Device["User Browser"]
    UI["Spotilytics UI (Rails views + Turbo / JS)"]
    Cookie["Session Cookie"]
  end

  subgraph Heroku["Heroku Dyno(s)"]
    Rails["Rails App"]
    SClient["SpotifyClient (service)"]
    Hist["ListeningHistory (service)"]
    Persona["MusicPersonality (service)"]
    Views["ERB Views / Partials"]
    RailsCache["Rails.cache API"]
  end

  subgraph Heroku_Addons["Heroku Add-ons"]
    Redis["Redis (redis_cache_store)\nnamespace: spotilytics-cache\nTTL: 24h"]
    DB["PostgreSQL / SQLite\n(listening_plays, top_track_batches, etc.)"]
  end

  subgraph SpotifyCloud["Spotify Platform"]
    OAuth["Spotify Accounts (OAuth2)"]
    WebAPI["Spotify Web API"]
  end

  %% Browser <> Rails
  User_Device -->|HTTPS| Rails
  Rails -->|Reads/Writes| Cookie

  %% OAuth
  Rails -->|OAuth redirect| OAuth
  OAuth -->|Auth code / tokens| Rails

  %% App <-> Client <-> API
  Rails --> SClient
  Rails --> Hist
  Rails --> Persona
  SClient -->|REST| WebAPI
  Hist --> DB
  Rails -->|ActiveRecord| DB

  %% Caching path
  Rails -->|read/write| RailsCache
  RailsCache <--> Redis

  %% Cache flow semantics
  SClient -. "cache_for([...])\nRails.cache.fetch(key)" .-> RailsCache
  RailsCache -. "hit → return data" .-> SClient
  RailsCache -. "miss → fetch via API\nstore in Redis" .-> SClient

  %% CI
  subgraph CI["GitHub Actions"]
    Lint["Rubocop / Brakeman"]
    Tests["RSpec + Cucumber"]
    Coverage["SimpleCov Collate (RSpec+Cucumber)"]
    Deploy["Heroku Deploy"]
  end

  CI --> Heroku
