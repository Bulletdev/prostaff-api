# frozen_string_literal: true

# Parameter Validation Concern
#
# Provides helper methods for validating and sanitizing controller parameters.
# Helps prevent nil errors and improves input validation across controllers.
#
# @example Usage in a controller
#   class MyController < ApplicationController
#     include ParameterValidation
#
#     def index
#       # Validate required parameter
#       validate_required_param!(:user_id)
#
#       # Validate with custom error message
#       validate_required_param!(:email, message: 'Email is required')
#
#       # Validate enum value
#       status = validate_enum_param(:status, %w[active inactive])
#
#       # Get integer with default
#       page = integer_param(:page, default: 1, min: 1)
#     end
#   end
#
module ParameterValidation
  extend ActiveSupport::Concern

  # Validates that a required parameter is present
  #
  # @param param_name [Symbol] Name of the parameter to validate
  # @param message [String] Custom error message (optional)
  # @raise [ActionController::ParameterMissing] if parameter is missing or blank
  # @return [String] The parameter value
  #
  # @example
  #   validate_required_param!(:email)
  #   # => "user@example.com" or raises error
  def validate_required_param!(param_name, message: nil)
    value = params[param_name]

    if value.blank?
      error_message = message || "#{param_name.to_s.humanize} is required"
      raise ActionController::ParameterMissing.new(param_name), error_message
    end

    value
  end

  # Validates that a parameter matches one of the allowed values
  #
  # @param param_name [Symbol] Name of the parameter to validate
  # @param allowed_values [Array] Array of allowed values
  # @param default [Object] Default value if parameter is missing (optional)
  # @param message [String] Custom error message (optional)
  # @return [String, Object] The validated parameter value or default
  # @raise [ArgumentError] if value is not in allowed_values
  #
  # @example
  #   validate_enum_param(:status, %w[active inactive], default: 'active')
  #   # => "active"
  def validate_enum_param(param_name, allowed_values, default: nil, message: nil)
    value = params[param_name]

    return default if value.blank? && default.present?

    if value.present? && !allowed_values.include?(value)
      error_message = message || "#{param_name.to_s.humanize} must be one of: #{allowed_values.join(', ')}"
      raise ArgumentError, error_message
    end

    value || default
  end

  # Extracts and validates an integer parameter
  #
  # @param param_name [Symbol] Name of the parameter
  # @param default [Integer] Default value if parameter is missing
  # @param min [Integer] Minimum allowed value (optional)
  # @param max [Integer] Maximum allowed value (optional)
  # @return [Integer] The validated integer value
  # @raise [ArgumentError] if value is not a valid integer or out of range
  #
  # @example
  #   integer_param(:page, default: 1, min: 1, max: 100)
  #   # => 1
  def integer_param(param_name, default: nil, min: nil, max: nil)
    value = params[param_name]

    return default if value.blank?

    begin
      int_value = Integer(value)
    rescue ArgumentError, TypeError
      raise ArgumentError, "#{param_name.to_s.humanize} must be a valid integer"
    end

    raise ArgumentError, "#{param_name.to_s.humanize} must be at least #{min}" if min.present? && int_value < min

    raise ArgumentError, "#{param_name.to_s.humanize} must be at most #{max}" if max.present? && int_value > max

    int_value
  end

  # Extracts and validates a boolean parameter
  #
  # @param param_name [Symbol] Name of the parameter
  # @param default [Boolean] Default value if parameter is missing
  # @return [Boolean] The boolean value
  #
  # @example
  #   boolean_param(:active, default: true)
  #   # => true
  def boolean_param(param_name, default: false)
    value = params[param_name]

    return default unless value

    ActiveModel::Type::Boolean.new.cast(value)
  end

  # Extracts and validates a date parameter
  #
  # @param param_name [Symbol] Name of the parameter
  # @param default [Date] Default value if parameter is missing
  # @return [Date, nil] The date value
  # @raise [ArgumentError] if value is not a valid date
  #
  # @example
  #   date_param(:start_date)
  #   # => Date object or nil
  def date_param(param_name, default: nil)
    value = params[param_name]

    return default if value.blank?

    begin
      Date.parse(value.to_s)
    rescue ArgumentError
      raise ArgumentError, "#{param_name.to_s.humanize} must be a valid date"
    end
  end

  # Validates and sanitizes email parameter
  #
  # @param param_name [Symbol] Name of the parameter
  # @param required [Boolean] Whether the parameter is required
  # @return [String, nil] Normalized email (lowercase, stripped)
  # @raise [ArgumentError] if email format is invalid
  #
  # @example
  #   email_param(:email, required: true)
  #   # => "user@example.com"
  def email_param(param_name, required: false)
    value = params[param_name]

    raise ArgumentError, "#{param_name.to_s.humanize} is required" if required && value.blank?

    return nil if value.blank?

    email = value.to_s.downcase.strip

    unless email.match?(URI::MailTo::EMAIL_REGEXP)
      raise ArgumentError, "#{param_name.to_s.humanize} must be a valid email address"
    end

    email
  end

  # Validates array parameter
  #
  # @param param_name [Symbol] Name of the parameter
  # @param default [Array] Default value if parameter is missing
  # @param max_size [Integer] Maximum array size (optional)
  # @return [Array] The array value
  # @raise [ArgumentError] if not an array or exceeds max size
  #
  # @example
  #   array_param(:tags, default: [], max_size: 10)
  #   # => ["tag1", "tag2"]
  def array_param(param_name, default: [], max_size: nil)
    value = params[param_name]

    return default if value.blank?

    raise ArgumentError, "#{param_name.to_s.humanize} must be an array" unless value.is_a?(Array)

    if max_size.present? && value.size > max_size
      raise ArgumentError, "#{param_name.to_s.humanize} cannot contain more than #{max_size} items"
    end

    value
  end

  # Sanitizes string parameter (strips whitespace)
  #
  # @param param_name [Symbol] Name of the parameter
  # @param default [String] Default value if parameter is missing
  # @param max_length [Integer] Maximum string length (optional)
  # @return [String, nil] Sanitized string
  # @raise [ArgumentError] if exceeds max_length
  #
  # @example
  #   string_param(:name, max_length: 255)
  #   # => "John Doe"
  def string_param(param_name, default: nil, max_length: nil)
    value = params[param_name]

    return default if value.blank?

    string = value.to_s.strip

    if max_length.present? && string.length > max_length
      raise ArgumentError, "#{param_name.to_s.humanize} cannot be longer than #{max_length} characters"
    end

    string
  end
end
