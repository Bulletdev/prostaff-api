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
      skip_before_action :authenticate_request!, only: %i[register login player_login forgot_password reset_password refresh]

      # Registers a new user and organization
      #
      # Creates a new organization and assigns the user as the owner.
      # Sends a welcome email and returns JWT tokens for immediate authentication.
      #
      # POST /api/v1/auth/register
      #
      # @return [JSON] User, organization, and JWT tokens
      def register
        # Check for duplicate email
        email = params.dig(:user, :email)&.downcase&.strip
        if email.present? && User.exists?(email: email)
          return render_error(
            message: 'Já existe uma conta com este email. Por favor, faça login ou use outro email.',
            code: 'DUPLICATE_EMAIL',
            status: :unprocessable_entity
          )
        end

        # Check for duplicate organization name
        org_name = params.dig(:organization, :name)&.strip
        if org_name.present? && Organization.exists?(['LOWER(name) = ?', org_name.downcase])
          return render_error(
            message: 'Já existe uma organização com este nome. Por favor, escolha outro nome.',
            code: 'DUPLICATE_ORGANIZATION',
            status: :unprocessable_entity
          )
        end

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

          deliver_email(UserMailer.welcome(user))

          render_created(
            {
              user: JSON.parse(UserSerializer.render(user)),
              organization: JSON.parse(OrganizationSerializer.render(organization))
            }.merge(tokens),
            message: "Registration successful. Your #{organization.trial_days_remaining}-day trial has started!"
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
              organization: JSON.parse(OrganizationSerializer.render(user.organization))
            }.merge(tokens),
            message: 'Login successful'
          )
        else
          render_error(
            message: 'Invalid credentials',
            code: 'INVALID_CREDENTIALS',
            status: :unauthorized
          )
        end
      rescue StandardError => e
        Rails.logger.error("Login error: #{e.class} - #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
        render_error(
          message: 'Invalid credentials',
          code: 'INVALID_CREDENTIALS',
          status: :unauthorized
        )
      end

      # Authenticates a player using player-specific credentials
      #
      # Validates player_email + password, requires player_access_enabled.
      # Returns a player-scoped JWT (entity_type: 'player') with limited permissions.
      #
      # POST /api/v1/auth/player-login
      #
      # @param player_email [String] The player's individual access email
      # @param password [String] The player's individual access password
      # @return [JSON] Player info and JWT tokens
      def player_login
        player_email = params[:player_email]&.downcase&.strip
        password     = params[:password]

        if player_email.blank? || password.blank?
          return render_error(
            message: 'Email e senha são obrigatórios',
            code: 'MISSING_CREDENTIALS',
            status: :bad_request
          )
        end

        player = Player.find_by(player_email: player_email)

        unless player&.has_player_access? && player.authenticate_player_password(password)
          return render_error(
            message: 'Credenciais inválidas ou acesso não habilitado',
            code: 'INVALID_CREDENTIALS',
            status: :unauthorized
          )
        end

        tokens = Authentication::Services::JwtService.generate_player_tokens(player)
        player.update_last_login!

        render_success(
          {
            player: {
              id:                player.id,
              name:              player.real_name.presence || player.summoner_name,
              professional_name: player.professional_name,
              summoner_name:     player.summoner_name,
              role:              player.role,
              status:            player.status,
              country:           player.country,
              profile_icon_id:   player.profile_icon_id,
              avatar_url:        player.avatar_url.presence,
              organization_id:   player.organization_id,
              organization_name: player.organization&.name,
              # Rank
              solo_queue_tier:   player.solo_queue_tier,
              solo_queue_rank:   player.solo_queue_rank,
              solo_queue_lp:     player.solo_queue_lp,
              solo_queue_wins:   player.solo_queue_wins,
              solo_queue_losses: player.solo_queue_losses,
              flex_queue_tier:   player.flex_queue_tier,
              flex_queue_rank:   player.flex_queue_rank,
              flex_queue_lp:     player.flex_queue_lp,
              peak_tier:         player.peak_tier,
              peak_rank:         player.peak_rank,
              peak_season:       player.peak_season,
              # Performance
              win_rate:          player.win_rate,
              # Champions
              main_champions:    player.main_champions,
              # Social
              twitter_handle:    player.twitter_handle,
              twitch_channel:    player.twitch_channel,
            }
          }.merge(tokens),
          message: 'Login realizado com sucesso'
        )
      rescue StandardError => e
        Rails.logger.error("Player login error: #{e.class} - #{e.message}")
        render_error(message: 'Credenciais inválidas', code: 'INVALID_CREDENTIALS', status: :unauthorized)
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
        token = request.headers['Authorization']&.split&.last
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

          deliver_email(UserMailer.password_reset(user, reset_token))

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

          deliver_email(UserMailer.password_reset_confirmation(user))

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

      # Deliver email using async queue if Redis available, otherwise deliver synchronously
      def deliver_email(mailer)
        if ENV['REDIS_URL'].present?
          mailer.deliver_later
        else
          mailer.deliver_now
        end
      end

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

        # Bypass RLS for login - we don't have RLS context yet during authentication
        user = User.unscoped.find_by(email: email)
        user&.authenticate(password) ? user : nil
      end

      def organization_params
        permitted = params.require(:organization).permit(:name, :region, :tier)
        # Normalize region to uppercase to match Constants::REGIONS format
        permitted[:region] = permitted[:region]&.upcase if permitted[:region].present?
        permitted
      end

      def user_params
        params.require(:user).permit(:email, :password, :full_name, :timezone, :language)
      end
    end
  end
end
