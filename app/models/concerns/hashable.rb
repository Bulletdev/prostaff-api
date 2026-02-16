# frozen_string_literal: true

# Hashable Concern
# Adds HashID encoding/decoding capabilities to ActiveRecord models with UUID primary keys
#
# @see config/initializers/hashid.rb

module Hashable
  extend ActiveSupport::Concern

  included do
    def hashid
      return nil if id.blank?

      numeric_id = uuid_to_numeric(id)

      hashids_instance.encode(numeric_id)
    rescue StandardError => e
      Rails.logger.error "[HASHID] Failed to encode #{self.class.name}##{id}: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      nil
    end

    # Alternative shorter method name
    alias_method :to_hashid, :hashid

    # @example
    #   vod.public_hashid_url # => "https://prostaff.gg/vod-reviews/Zx1U3mA7caXq"
    def public_hashid_url
      return nil unless hashid.present?
      return nil unless ENV['FRONTEND_URL'].present?

      "#{ENV['FRONTEND_URL']}/#{self.class.name.underscore.pluralize}/#{hashid}"
    end

    private

    # Get Hashids instance with proper configuration
    # @return [Hashids] Configured Hashids instance
    def hashids_instance
      salt = ENV.fetch('HASHID_SALT', 'development_fallback_salt')
      min_length = ENV.fetch('HASHID_MIN_LENGTH', '6').to_i
      alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

      full_salt = "#{salt}#{self.class.table_name}"

      Hashids.new(full_salt, min_length, alphabet)
    end

    # Convert UUID to numeric value
    # @param uuid [String] UUID string (e.g., "5c8d9b3e-3155-4871-a419-e72ad5f21c19")
    # @return [Integer] Numeric representation (128-bit integer)
    def uuid_to_numeric(uuid)
      uuid.delete('-').to_i(16)
    end
  end

  class_methods do
    # Find record by HashID
    # @param hashid [String] The HashID to decode
    # @return [ActiveRecord::Base, nil] The found record or nil
    # @example
    #   VodReview.find_by_hashid("mA7cXq") # => #<VodReview:0x00...>
    def find_by_hashid(hashid)
      return nil if hashid.blank?

      numeric_id = hashids_instance.decode(hashid).first
      return nil if numeric_id.nil?

      uuid = numeric_to_uuid(numeric_id)
      find_by(id: uuid)
    rescue StandardError => e
      Rails.logger.error "[HASHID] Failed to decode hashid '#{hashid}' for #{name}: #{e.message}"
      Rails.logger.error e.backtrace.first(3).join("\n")
      nil
    end

    def find_by_hashid!(hashid)
      find_by_hashid(hashid) or raise ActiveRecord::RecordNotFound, "Couldn't find #{name} with hashid=#{hashid}"
    end

    private

    # Get Hashids instance with proper configuration (class method)
    # @return [Hashids] Configured Hashids instance
    def hashids_instance
      salt = ENV.fetch('HASHID_SALT', 'development_fallback_salt')
      min_length = ENV.fetch('HASHID_MIN_LENGTH', '6').to_i
      alphabet = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

      # Add table name as pepper
      full_salt = "#{salt}#{table_name}"

      Hashids.new(full_salt, min_length, alphabet)
    end

    # Convert numeric value to UUID string
    # @param numeric [Integer] Numeric representation of UUID (128-bit integer)
    # @return [String] UUID string (e.g., "5c8d9b3e-3155-4871-a419-e72ad5f21c19")
    def numeric_to_uuid(numeric)
      # Convert to hex and pad to 32 characters
      hex = numeric.to_s(16).rjust(32, '0')

      # Format as UUID: 8-4-4-4-12
      "#{hex[0..7]}-#{hex[8..11]}-#{hex[12..15]}-#{hex[16..19]}-#{hex[20..31]}"
    end
  end
end
