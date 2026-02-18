# frozen_string_literal: true

module ApplicationCable
  # Base class for all Action Cable channels.
  #
  # Provides access to the authenticated user and their organization
  # for all channels that inherit from this class.
  class Channel < ActionCable::Channel::Base
    # Delegate current_user and current_org_id from the connection
    delegate :current_user, :current_org_id, to: :connection
  end
end
