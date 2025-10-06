class JwtAuthentication
  def initialize(app)
    @app = app
  end

  def call(env)
    begin
      authenticate_request(env)
    rescue Authentication::Services::JwtService::AuthenticationError => e
      return unauthorized_response(e.message)
    end

    @app.call(env)
  end

  private

  def authenticate_request(env)
    request = Rack::Request.new(env)

    # Skip authentication for certain paths
    return if skip_authentication?(request.path_info)

    token = extract_token(request)
    return if token.nil? # Let controller handle missing token

    # Decode and verify token
    payload = Authentication::Services::JwtService.decode(token)
    user = User.find(payload[:user_id])

    # Store user info in environment for controllers
    env['rack.jwt.payload'] = payload
    env['current_user'] = user
    env['current_organization'] = user.organization

  rescue ActiveRecord::RecordNotFound
    raise Authentication::Services::JwtService::AuthenticationError, 'User not found'
  end

  def extract_token(request)
    # Check Authorization header
    auth_header = request.get_header('HTTP_AUTHORIZATION')
    return nil unless auth_header

    # Extract Bearer token
    match = auth_header.match(/Bearer\s+(.+)/i)
    match&.[](1)
  end

  def skip_authentication?(path)
    # Paths that don't require authentication
    skip_paths = [
      '/api/v1/auth/login',
      '/api/v1/auth/register',
      '/api/v1/auth/forgot-password',
      '/api/v1/auth/reset-password',
      '/up', # Health check
    ]

    skip_paths.any? { |skip_path| path.start_with?(skip_path) }
  end

  def unauthorized_response(message = 'Unauthorized')
    [
      401,
      { 'Content-Type' => 'application/json' },
      [{ error: { code: 'UNAUTHORIZED', message: message } }.to_json]
    ]
  end
end