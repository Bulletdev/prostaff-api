# frozen_string_literal: true

# Controller para gerar sitemap.xml dinamicamente
class SitemapController < ApplicationController
  skip_before_action :authenticate_request!, only: [:index]

  # GET /sitemap.xml
  def index
    @base_url = ENV.fetch('APP_URL', 'https://prostaff.gg')
    @current_time = Time.current.iso8601

    respond_to do |format|
      format.xml { render template: 'sitemap/index', layout: false }
    end
  end
end
