# frozen_string_literal: true

module Api
  module V1
    class NotificationsController < Api::V1::BaseController
      before_action :set_notification, only: %i[show mark_as_read]

      # GET /api/v1/notifications
      def index
        notifications = current_user.notifications.recent

        notifications = notifications.unread if params[:unread] == 'true'
        notifications = notifications.by_type(params[:type]) if params[:type].present?

        result = paginate(notifications)

        render_success({
                         notifications: NotificationSerializer.render_as_hash(result[:data]),
                         total: result[:pagination][:total_count],
                         page: result[:pagination][:current_page],
                         per_page: result[:pagination][:per_page],
                         total_pages: result[:pagination][:total_pages],
                         unread_count: current_user.notifications.unread.count
                       })
      end

      # GET /api/v1/notifications/:id
      def show
        render_success({
                         notification: NotificationSerializer.render_as_hash(@notification)
                       })
      end

      # PATCH /api/v1/notifications/:id/mark_as_read
      def mark_as_read
        @notification.mark_as_read!

        render_success({
                         notification: NotificationSerializer.render_as_hash(@notification)
                       }, message: 'Notification marked as read')
      end

      # PATCH /api/v1/notifications/mark_all_as_read
      def mark_all_as_read
        count = current_user.notifications.unread.count
        current_user.notifications.unread.update_all(is_read: true, read_at: Time.current)

        render_success({
                         marked_count: count
                       }, message: "#{count} notifications marked as read")
      end

      # GET /api/v1/notifications/unread_count
      def unread_count
        render_success({
                         unread_count: current_user.notifications.unread.count
                       })
      end

      # DELETE /api/v1/notifications/:id
      def destroy
        @notification = current_user.notifications.find(params[:id])
        @notification.destroy!

        render_deleted(message: 'Notification deleted successfully')
      rescue ActiveRecord::RecordNotFound
        render_not_found('Notification not found')
      end

      private

      def set_notification
        @notification = current_user.notifications.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render_not_found('Notification not found')
      end
    end
  end
end
