module Authentication
  module Controllers
    class AuthController < Api::V1::BaseController
      skip_before_action :authenticate_request!, only: [:register, :login, :forgot_password, :reset_password, :refresh]

      # POST /api/v1/auth/register
      def register
        ActiveRecord::Base.transaction do
          organization = create_organization!
          user = create_user!(organization)
          tokens = Authentication::Services::JwtService.generate_tokens(user)

          log_user_action(
            action: 'register',
            entity_type: 'User',
            entity_id: user.id
          )

          UserMailer.welcome(user).deliver_later

          render_created(
            {
              user: UserSerializer.new(user).serializable_hash[:data][:attributes],
              organization: OrganizationSerializer.new(organization).serializable_hash[:data][:attributes],
              **tokens
            },
            message: 'Registration successful'
          )
        end
      rescue ActiveRecord::RecordInvalid => e
        render_validation_errors(e)
      rescue => e
        render_error(message: 'Registration failed', code: 'REGISTRATION_ERROR')
      end

      # POST /api/v1/auth/login
      def login
        user = authenticate_user!

        if user
          tokens = Authentication::Services::JwtService.generate_tokens(user)
          user.update_last_login!

          log_user_action(
            action: 'login',
            entity_type: 'User',
            entity_id: user.id
          )

          render_success(
            {
              user: UserSerializer.new(user).serializable_hash[:data][:attributes],
              organization: OrganizationSerializer.new(user.organization).serializable_hash[:data][:attributes],
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

      # POST /api/v1/auth/refresh
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

      # POST /api/v1/auth/logout
      def logout
        token = request.headers['Authorization']&.split(' ')&.last
        Authentication::Services::JwtService.blacklist_token(token) if token

        log_user_action(
          action: 'logout',
          entity_type: 'User',
          entity_id: current_user.id
        )

        render_success({}, message: 'Logout successful')
      end

      # POST /api/v1/auth/forgot-password
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

          log_user_action(
            action: 'password_reset_requested',
            entity_type: 'User',
            entity_id: user.id
          )
        end

        render_success(
          {},
          message: 'If the email exists, a password reset link has been sent'
        )
      end

      # POST /api/v1/auth/reset-password
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

          log_user_action(
            action: 'password_reset_completed',
            entity_type: 'User',
            entity_id: user.id
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

      # GET /api/v1/auth/me
      def me
        render_success(
          {
            user: UserSerializer.new(current_user).serializable_hash[:data][:attributes],
            organization: OrganizationSerializer.new(current_organization).serializable_hash[:data][:attributes]
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