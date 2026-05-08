# frozen_string_literal: true

module Api
  module V1
    # Handles public contact form submissions from prostaff.gg/contact
    class ContactController < ApplicationController
      def create
        name    = params.require(:name)
        email   = params.require(:email)
        subject = params.require(:subject)
        message = params.require(:message)

        ContactMailer.new_message(
          name: name,
          email: email,
          subject: subject,
          message: message
        ).deliver_later

        render json: { message: 'Message sent successfully' }, status: :ok
      rescue ActionController::ParameterMissing => e
        render json: { error: { message: "Missing required parameter: #{e.param}" } }, status: :bad_request
      end
    end
  end
end
