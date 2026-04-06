# frozen_string_literal: true

# Handles file uploads to Supabase S3-compatible storage
class S3UploadService
  ALLOWED_CONTENT_TYPES = %w[
    image/jpeg
    image/png
    image/gif
    image/webp
    application/pdf
    text/plain
    text/csv
  ].freeze

  MAX_SIZE_MB = 10
  MAX_SIZE_BYTES = MAX_SIZE_MB * 1024 * 1024
  SIGNED_URL_EXPIRY = 3600 # 1 hour

  def initialize
    @client = Aws::S3::Client.new(
      access_key_id: ENV.fetch('SUPABASE_S3_ACCESS_KEY'),
      secret_access_key: ENV.fetch('SUPABASE_S3_SECRET_KEY'),
      region: ENV.fetch('SUPABASE_S3_REGION', 'sa-east-1'),
      endpoint: ENV.fetch('SUPABASE_S3_ENDPOINT'),
      force_path_style: true
    )
    @bucket = ENV.fetch('SUPABASE_S3_BUCKET')
  end

  # Upload a file and return its metadata (does not include signed URL)
  #
  # @param file [ActionDispatch::Http::UploadedFile] the uploaded file
  # @param prefix [String] S3 key prefix (e.g. "support/user-uuid")
  # @return [Hash] { key:, filename:, content_type:, size: }
  def upload(file, prefix: 'support')
    validate!(file)

    key = generate_key(file.original_filename, prefix)

    @client.put_object(
      bucket: @bucket,
      key: key,
      body: file.read,
      content_type: file.content_type,
      content_disposition: "inline; filename=\"#{file.original_filename}\""
    )

    {
      key: key,
      filename: file.original_filename,
      content_type: file.content_type,
      size: file.size
    }
  end

  # Generate a pre-signed GET URL for a stored object
  #
  # @param key [String] the S3 object key
  # @param expires_in [Integer] expiry in seconds (max 604800 for AWS S3 Signature V4)
  # @return [String] signed URL
  def signed_url(key, expires_in: SIGNED_URL_EXPIRY)
    # AWS S3 Signature V4 caps at 7 days; clamp to be safe
    capped = [expires_in, 604_800].min
    signer = Aws::S3::Presigner.new(client: @client)
    signer.presigned_url(:get_object, bucket: @bucket, key: key, expires_in: capped)
  rescue StandardError => e
    Rails.logger.error("[S3UploadService] Failed to generate signed URL for #{key}: #{e.message}")
    nil
  end

  # Build a permanent public URL for the object (requires the bucket to allow public access).
  # Supabase format: {project_base}/storage/v1/object/public/{bucket}/{key}
  #
  # @param key [String] the S3 object key
  # @return [String] public URL
  def public_url(key)
    # Strip the S3 path suffix to get the project base URL
    # SUPABASE_S3_ENDPOINT = https://xxx.storage.supabase.co/storage/v1/s3
    base = ENV.fetch('SUPABASE_S3_ENDPOINT').sub(%r{/s3\z}, '')
    "#{base}/object/public/#{@bucket}/#{key}"
  end

  private

  def validate!(file)
    unless ALLOWED_CONTENT_TYPES.include?(file.content_type)
      raise ArgumentError, "File type not allowed. Allowed: #{ALLOWED_CONTENT_TYPES.join(', ')}"
    end

    return unless file.size > MAX_SIZE_BYTES

    raise ArgumentError, "File too large. Maximum size is #{MAX_SIZE_MB}MB"
  end

  def generate_key(filename, prefix)
    ext = File.extname(filename).downcase
    "#{prefix}/#{SecureRandom.uuid}#{ext}"
  end
end
