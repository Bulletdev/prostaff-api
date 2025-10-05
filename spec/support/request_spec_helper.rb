module RequestSpecHelper
  # Helper method to generate JWT token for testing
  def auth_token(user)
    Authentication::Services::JwtService.encode(user_id: user.id)
  end

  # Helper method to set authentication headers
  def auth_headers(user)
    {
      'Authorization' => "Bearer #{auth_token(user)}",
      'Content-Type' => 'application/json'
    }
  end

  # Helper to parse JSON response
  def json_response
    JSON.parse(response.body, symbolize_names: true)
  end
end
