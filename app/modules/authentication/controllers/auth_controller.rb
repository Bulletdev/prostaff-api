# frozen_string_literal: true

module Authentication
  module Controllers
    # Authentication Controller
    #
    # Handles all authentication-related operations including user registration,
    # login, logout, token refresh, and password reset flows.
    #
    # Features:
    # - JWT-based authentication with access and refresh tokens
    # - Secure password reset via email
    # - Audit logging for all auth events
    # - Token blacklisting for logout
    #
    # @example Register a new user
    #   POST /api/v1/auth/register
    #   {
    #     "user": { "email": "user@example.com", "password": "secret" },
    #     "organization": { "name": "My Team", "region": "BR" }
    #   }
    #
    # @example Login
    #   POST /api/v1/auth/login
    #   { "email": "user@example.com", "password": "secret" }
    #
    class AuthController < Api::V1::BaseController
      skip_before_action :authenticate_request!, only: [:register, :login, :forgot_password, :reset_password, :refresh]

      # Registers a new user and organization
      #
      # Creates a new organization and assigns the user as the owner.
      # Sends a welcome email and returns JWT tokens for immediate authentication.
      #
      # POST /api/v1/auth/register
      #
      # @return [JSON] User, organization, and JWT tokens
      def register
        ActiveRecord::Base.transaction do
          organization = create_organization!
          user = create_user!(organization)
          tokens = Authentication::Services::JwtService.generate_tokens(user)

          AuditLog.create!(
            organization: organization,
            user: user,
            action: 'register',
            entity_type: 'User',
            entity_id: user.id,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )

          UserMailer.welcome(user).deliver_later

          render_created(
            {
              user: JSON.parse(UserSerializer.render(user)),
              organization: JSON.parse(OrganizationSerializer.render(organization)),
              **tokens
            },
            message: 'Registration successful'
          )
        end
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e)
      rescue StandardError => _e
        render_error(message: 'Registration failed', code: 'REGISTRATION_ERROR')
      end

      # Authenticates a user and returns JWT tokens
      #
      # Validates credentials and generates access/refresh tokens.
      # Updates the user's last login timestamp and logs the event.
      #
      # POST /api/v1/auth/login
      #
      # @return [JSON] User, organization, and JWT tokens
      def login
        user = authenticate_user!

        if user
          tokens = Authentication::Services::JwtService.generate_tokens(user)
          user.update_last_login!

          AuditLog.create!(
            organization: user.organization,
            user: user,
            action: 'login',
            entity_type: 'User',
            entity_id: user.id,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )

          render_success(
            {
              user: JSON.parse(UserSerializer.render(user)),
              organization: JSON.parse(OrganizationSerializer.render(user.organization)),
              **tokens
            },
            message: 'Login successful'
          )
        else
          render_error(
            message: 'Invalid email or password',
            code: 'INVALID_CREDENTIALS',
            status: :unauthorized
          )
        end
      end

      # Refreshes an access token using a refresh token
      #
      # Validates the refresh token and generates a new access token.
      #
      # POST /api/v1/auth/refresh
      #
      # @param refresh_token [String] The refresh token from previous authentication
      # @return [JSON] New access token and refresh token
      def refresh
        refresh_token = params[:refresh_token]

        if refresh_token.blank?
          return render_error(
            message: 'Refresh token is required',
            code: 'MISSING_REFRESH_TOKEN',
            status: :bad_request
          )
        end

        begin
          tokens = Authentication::Services::JwtService.refresh_access_token(refresh_token)
          render_success(tokens, message: 'Token refreshed successfully')
        rescue Authentication::Services::JwtService::AuthenticationError => e
          render_error(
            message: e.message,
            code: 'INVALID_REFRESH_TOKEN',
            status: :unauthorized
          )
        end
      end

      # Logs out the current user
      #
      # Blacklists the current access token to prevent further use.
      # The user must login again to obtain new tokens.
      #
      # POST /api/v1/auth/logout
      #
      # @return [JSON] Success message
      def logout
        # Blacklist the current access token
        token = request.headers['Authorization']&.split(' ')&.last
        Authentication::Services::JwtService.blacklist_token(token) if token

        log_user_action(
          action: 'logout',
          entity_type: 'User',
          entity_id: current_user.id
        )

        render_success({}, message: 'Logout successful')
      end

      # Initiates password reset flow
      #
      # Generates a password reset token and sends it via email.
      # Always returns success to prevent email enumeration.
      #
      # POST /api/v1/auth/forgot-password
      #
      # @param email [String] User's email address
      # @return [JSON] Success message
      def forgot_password
        email = params[:email]&.downcase&.strip

        if email.blank?
          return render_error(
            message: 'Email is required',
            code: 'MISSING_EMAIL',
            status: :bad_request
          )
        end

        user = User.find_by(email: email)

        if user
          reset_token = user.password_reset_tokens.create!(
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )

          UserMailer.password_reset(user, reset_token).deliver_later

          AuditLog.create!(
            organization: user.organization,
            user: user,
            action: 'password_reset_requested',
            entity_type: 'User',
            entity_id: user.id,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )
        end

        render_success(
          {},
          message: 'If the email exists, a password reset link has been sent'
        )
      end

      # Resets user password using reset token
      #
      # Validates the reset token and updates the user's password.
      # Marks the token as used and sends a confirmation email.
      #
      # POST /api/v1/auth/reset-password
      #
      # @param token [String] Password reset token from email
      # @param password [String] New password
      # @param password_confirmation [String] Password confirmation
      # @return [JSON] Success or error message
      def reset_password
        token = params[:token]
        new_password = params[:password]
        password_confirmation = params[:password_confirmation]

        if token.blank? || new_password.blank?
          return render_error(
            message: 'Token and password are required',
            code: 'MISSING_PARAMETERS',
            status: :bad_request
          )
        end

        if new_password != password_confirmation
          return render_error(
            message: 'Password confirmation does not match',
            code: 'PASSWORD_MISMATCH',
            status: :bad_request
          )
        end

        reset_token = PasswordResetToken.valid.find_by(token: token)

        if reset_token
          user = reset_token.user
          user.update!(password: new_password)

          reset_token.mark_as_used!

          UserMailer.password_reset_confirmation(user).deliver_later

          AuditLog.create!(
            organization: user.organization,
            user: user,
            action: 'password_reset_completed',
            entity_type: 'User',
            entity_id: user.id,
            ip_address: request.remote_ip,
            user_agent: request.user_agent
          )

          render_success({}, message: 'Password reset successful')
        else
          render_error(
            message: 'Invalid or expired reset token',
            code: 'INVALID_RESET_TOKEN',
            status: :bad_request
          )
        end
      end

      # Returns current authenticated user information
      #
      # GET /api/v1/auth/me
      #
      # @return [JSON] Current user and organization data
      def me
        render_success(
          {
            user: JSON.parse(UserSerializer.render(current_user)),
            organization: JSON.parse(OrganizationSerializer.render(current_organization))
          }
        )
      end

      private

      def create_organization!
        Organization.create!(organization_params)
      end

      def create_user!(organization)
        User.create!(user_params.merge(
          organization: organization,
          role: 'owner' # First user is always the owner
        ))
      end

      def authenticate_user!
        email = params[:email]&.downcase&.strip
        password = params[:password]

        return nil if email.blank? || password.blank?

        user = User.find_by(email: email)
        user&.authenticate(password) ? user : nil
      end

      def organization_params
        params.require(:organization).permit(:name, :region, :tier)
      end

      def user_params
        params.require(:user).permit(:email, :password, :full_name, :timezone, :language)
      end
    end
  end
end
