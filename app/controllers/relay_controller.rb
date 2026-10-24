# frozen_string_literal: true

class RelayController < ApplicationController
  def redirect
    target = params[:to].to_s
    return head :bad_request if target.blank?

    redirect_to target, allow_other_host: true, status: :found
  end
end
