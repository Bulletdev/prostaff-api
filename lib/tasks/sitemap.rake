# frozen_string_literal: true

namespace :sitemap do
  desc 'Generate sitemap.xml file'
  task generate: :environment do
    puts '  Generating sitemap.xml...'

    base_url = ENV.fetch('APP_URL', 'https://api.prostaff.gg')
    current_time = Time.current.iso8601

    sitemap_content = <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://www.sitemaps.org/schemas/sitemap/0.9
              http://www.sitemaps.org/schemas/sitemap/0.9/sitemap.xsd">

        <!-- API Documentation -->
        <url>
          <loc>#{base_url}/api-docs</loc>
          <lastmod>#{current_time}</lastmod>
          <changefreq>weekly</changefreq>
          <priority>0.9</priority>
        </url>

        <!-- Health Check -->
        <url>
          <loc>#{base_url}/health</loc>
          <lastmod>#{current_time}</lastmod>
          <changefreq>daily</changefreq>
          <priority>0.5</priority>
        </url>

        <!-- Public API Endpoints -->
        <url>
          <loc>#{base_url}/api/v1/constants</loc>
          <lastmod>#{current_time}</lastmod>
          <changefreq>monthly</changefreq>
          <priority>0.7</priority>
        </url>

        <url>
          <loc>#{base_url}/api/v1/riot-data/champions</loc>
          <lastmod>#{current_time}</lastmod>
          <changefreq>weekly</changefreq>
          <priority>0.6</priority>
        </url>

        <url>
          <loc>#{base_url}/api/v1/riot-data/items</loc>
          <lastmod>#{current_time}</lastmod>
          <changefreq>weekly</changefreq>
          <priority>0.6</priority>
        </url>

        <url>
          <loc>#{base_url}/api/v1/competitive-matches</loc>
          <lastmod>#{current_time}</lastmod>
          <changefreq>daily</changefreq>
          <priority>0.8</priority>
        </url>

        <url>
          <loc>#{base_url}/api/v1/scouting/players</loc>
          <lastmod>#{current_time}</lastmod>
          <changefreq>daily</changefreq>
          <priority>0.7</priority>
        </url>

        <url>
          <loc>#{base_url}/api/v1/scouting/regions</loc>
          <lastmod>#{current_time}</lastmod>
          <changefreq>monthly</changefreq>
          <priority>0.6</priority>
        </url>

        <url>
          <loc>#{base_url}/api/v1/support/faq</loc>
          <lastmod>#{current_time}</lastmod>
          <changefreq>weekly</changefreq>
          <priority>0.7</priority>
        </url>

      </urlset>
    XML

    # Write to public directory
    file_path = Rails.root.join('public', 'sitemap_static.xml')
    File.write(file_path, sitemap_content)

    puts " Sitemap generated successfully at: #{file_path}"
    puts "   Total URLs: #{sitemap_content.scan(/<url>/).count}"
  end

  desc 'Ping search engines with sitemap'
  task ping: :environment do
    base_url = ENV.fetch('APP_URL', 'https://api.prostaff.gg')
    sitemap_url = "#{base_url}/sitemap.xml"

    puts " Pinging search engines with sitemap: #{sitemap_url}"

    search_engines = [
      "https://www.google.com/ping?sitemap=#{CGI.escape(sitemap_url)}",
      "https://www.bing.com/ping?sitemap=#{CGI.escape(sitemap_url)}"
    ]

    search_engines.each do |ping_url|
      begin
        response = Net::HTTP.get_response(URI(ping_url))
        engine = ping_url.match(/https:\/\/www\.(\w+)\.com/)[1].capitalize
        if response.is_a?(Net::HTTPSuccess)
          puts "   #{engine} pinged successfully"
        else
          puts "   Error pinging #{engine}: #{response.code}"
        end
      rescue StandardError => e
        puts "   Error pinging #{ping_url.match(/https:\/\/www\.(\w+)\.com/)[1].capitalize}: #{e.message}"
      end
    end

    puts " Done!"
  end

  desc 'Generate and ping sitemap'
  task update: %i[generate ping]
end
