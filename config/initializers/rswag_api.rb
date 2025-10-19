Rswag::Api.configure do |c|
  # Specify a root folder where OpenAPI JSON files are located
  c.openapi_root = Rails.root.join('swagger').to_s

  # Inject a lambda function to alter the returned Swagger prior to serialization
  # c.swagger_filter = lambda { |swagger, env| swagger['host'] = env['HTTP_HOST'] }
end
