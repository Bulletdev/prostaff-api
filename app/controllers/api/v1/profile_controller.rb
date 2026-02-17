# frozen_string_literal: true

module Api
  module V1
    # Profile Controller
    # Manages user profile operations (view, update profile, change password, notification preferences)
    class ProfileController < Api::V1::BaseController

      # GET /api/v1/profile
      # Returns current user profile
      def show
        render json: UserSerializer.render(@current_user), status: :ok
      end

      # PATCH /api/v1/profile
      # Updates user profile information
      def update
        if @current_user.update(profile_params)
          log_profile_update
          render json: {
            message: 'Profile updated successfully',
            user: UserSerializer.render(@current_user)
          }, status: :ok
        else
          render json: { errors: @current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/profile/password
      # Changes user password
      def update_password
        unless @current_user.authenticate(password_params[:current_password])
          return render json: { error: 'Current password is incorrect' }, status: :unauthorized
        end

        if @current_user.update(password: password_params[:new_password])
          log_password_change
          render json: { message: 'Password updated successfully' }, status: :ok
        else
          render json: { errors: @current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/profile/notifications
      # Updates notification preferences
      def update_notifications
        if @current_user.update(notification_params)
          render json: {
            message: 'Notification preferences updated successfully',
            notifications_enabled: @current_user.notifications_enabled,
            notification_preferences: @current_user.notification_preferences
          }, status: :ok
        else
          render json: { errors: @current_user.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def profile_params
        params.require(:user).permit(:full_name, :avatar_url, :timezone, :language)
      end

      def password_params
        params.require(:user).permit(:current_password, :new_password)
      end

      def notification_params
        params.require(:user).permit(
          :notifications_enabled,
          notification_preferences: {}
        )
      end

      def log_profile_update
        AuditLog.create!(
          organization: @current_user.organization,
          user: @current_user,
          action: 'update_profile',
          entity_type: 'User',
          entity_id: @current_user.id,
          old_values: @current_user.previous_changes.transform_values(&:first),
          new_values: @current_user.previous_changes.transform_values(&:last)
        )
      end

      def log_password_change
        AuditLog.create!(
          organization: @current_user.organization,
          user: @current_user,
          action: 'change_password',
          entity_type: 'User',
          entity_id: @current_user.id,
          old_values: {},
          new_values: { password_changed_at: Time.current }
        )
      end
    end
  end
end
