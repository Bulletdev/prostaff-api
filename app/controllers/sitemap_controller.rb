# frozen_string_literal: true

# Controller para gerar sitemap.xml dinamicamente
class SitemapController < ApplicationController
  # No authentication required for sitemap - it's a public endpoint
  # Note: authenticate_request! is only defined in Api::V1::BaseController, not ApplicationController

  # GET /sitemap.xml
  def index
    @base_url = ENV.fetch('APP_URL', 'https://prostaff.gg')
    @current_time = Time.current.iso8601

    respond_to do |format|
      format.xml { render template: 'sitemap/index', layout: false }
    end
  end
end
