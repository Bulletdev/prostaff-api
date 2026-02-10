# frozen_string_literal: true

module Analytics
  module Services
    # Elasticsearch Client Service\n    # Handles connections and queries to Elasticsearch for analytics
    class ElasticsearchClient
      def initialize(url: ENV.fetch('ELASTICSEARCH_URL', 'http://localhost:9200'))
        @client = Elasticsearch::Client.new(url: url)
      end

      def ping
        @client.ping
      rescue StandardError => e
        Rails.logger.error("Elasticsearch ping failed: #{e.message}")
        false
      end

      def search(index:, body: {})
        @client.search(index: index, body: body)
      end
    end
  end
end
