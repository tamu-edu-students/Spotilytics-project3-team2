require "rspotify/oauth"

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :spotify,
           ENV.fetch("SPOTIFY_CLIENT_ID"),
           ENV.fetch("SPOTIFY_CLIENT_SECRET"),
           scope: "user-read-email user-read-private user-top-read playlist-modify-private playlist-modify-public user-follow-read user-follow-modify user-library-read",
           authorize_params: { show_dialog: "true" }
end

OmniAuth.config.allowed_request_methods = %i[post get]
OmniAuth.config.silence_get_warning = true

OmniAuth.config.on_failure = Proc.new { |env|
  # Tells OmniAuth to redirect to your failure route instead of throwing an exception
  SessionsController.action(:failure).call(env)
}
