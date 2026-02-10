# frozen_string_literal: true

module Support
  # Chatbot service using Ruby LLM for intelligent ticket triage
  # Can use OpenAI, Anthropic Claude, or other LLM providers
  class ChatbotService
    CONFIDENCE_THRESHOLD = 0.7

    INTENT_KEYWORDS = {
      riot_integration: %w[riot api import match sync puuid summoner rate limit 403 401 429],
      billing: %w[payment subscription plan upgrade downgrade invoice card],
      technical: %w[error bug crash freeze slow loading broken],
      features: %w[how where feature request suggestion],
      getting_started: %w[start begin setup install configure first]
    }.freeze

    def initialize(ticket)
      @ticket = ticket
      @description = ticket.description
      @use_llm = ENV['CHATBOT_USE_LLM'] == 'true'
    end

    def generate_suggestions
      if @use_llm && llm_available?
        generate_llm_suggestions
      else
        generate_keyword_suggestions
      end
    end

    private

    # LLM-based suggestions using ruby-openai or similar
    def generate_llm_suggestions
      Rails.logger.info("🤖 Using LLM for chatbot response")

      # Build context from FAQs
      faq_context = build_faq_context

      prompt = build_llm_prompt(faq_context)

      begin
        response = call_llm(prompt)
        parse_llm_response(response)
      rescue StandardError => e
        Rails.logger.error("LLM Error: #{e.message}")
        # Fallback to keyword-based
        generate_keyword_suggestions
      end
    end

    def build_faq_context
      # Get top FAQs to provide context to LLM
      SupportFaq.published
                .by_locale(@ticket.user&.language || 'pt-BR')
                .ordered
                .limit(10)
                .map { |faq| "Q: #{faq.question}\nA: #{faq.answer.truncate(300)}" }
                .join("\n\n")
    end

    def build_llm_prompt(faq_context)
      <<~PROMPT
        You are a helpful support assistant for ProStaff.gg, an esports team management platform.

        User's issue:
        "#{@ticket.description}"

        Page URL: #{@ticket.page_url || 'N/A'}

        Available FAQ knowledge:
        #{faq_context}

        Based on the user's issue, please:
        1. Classify the intent (riot_integration, billing, technical, features, getting_started, or other)
        2. Provide 2-3 most relevant FAQ suggestions from the knowledge base
        3. Generate a helpful greeting message in Portuguese (pt-BR)
        4. Indicate if this should be escalated to a human (true/false)

        Respond in JSON format:
        {
          "intent": "category_name",
          "confidence": 0.0-1.0,
          "relevant_faq_ids": [1, 2, 3],
          "greeting": "Message in Portuguese",
          "should_escalate": true/false,
          "suggested_solution": "Brief solution if obvious"
        }
      PROMPT
    end

    def call_llm(prompt)
      # Using OpenAI as example, but can be replaced with Anthropic, etc.
      client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

      response = client.chat(
        parameters: {
          model: ENV['OPENAI_MODEL'] || 'gpt-4',
          messages: [
            { role: 'system', content: 'You are a support bot for ProStaff.gg' },
            { role: 'user', content: prompt }
          ],
          temperature: 0.3,
          max_tokens: 500
        }
      )

      response.dig('choices', 0, 'message', 'content')
    rescue StandardError => e
      Rails.logger.error("OpenAI API Error: #{e.message}")
      nil
    end

    def parse_llm_response(response)
      return generate_keyword_suggestions if response.nil?

      data = JSON.parse(response)

      # Find suggested FAQs
      faq_ids = data['relevant_faq_ids'] || []
      suggested_faqs = SupportFaq.where(id: faq_ids)

      {
        intent: data['intent'] || 'other',
        confidence: data['confidence'] || 0.5,
        suggestions: format_suggestions(suggested_faqs),
        should_escalate: data['should_escalate'] || false,
        greeting: data['greeting'] || generate_greeting(data['intent']),
        llm_solution: data['suggested_solution']
      }
    rescue JSON::ParserError
      Rails.logger.error("Failed to parse LLM response as JSON")
      generate_keyword_suggestions
    end

    # Keyword-based fallback (original implementation)
    def generate_keyword_suggestions
      Rails.logger.info("🔤 Using keyword matching for chatbot")

      intent = classify_intent
      confidence = calculate_confidence(intent)
      relevant_faqs = find_relevant_faqs(intent)

      {
        intent: intent,
        confidence: confidence,
        suggestions: format_suggestions(relevant_faqs),
        should_escalate: should_escalate?(confidence, relevant_faqs),
        greeting: generate_greeting(intent)
      }
    end

    def llm_available?
      ENV['OPENAI_API_KEY'].present? || ENV['ANTHROPIC_API_KEY'].present?
    end

    private

    def classify_intent
      # Score each category
      scores = INTENT_KEYWORDS.transform_values do |keywords|
        keywords.count { |keyword| @description.include?(keyword) }
      end

      # Return category with highest score
      scores.max_by { |_category, score| score }&.first || 'other'
    end

    def calculate_confidence(intent)
      return 0.0 if intent == 'other'

      keywords = INTENT_KEYWORDS[intent] || []
      matches = keywords.count { |keyword| @description.include?(keyword) }

      # Confidence based on keyword matches
      [matches.to_f / 5, 1.0].min
    end

    def find_relevant_faqs(intent)
      # Find FAQs by category
      category_faqs = SupportFaq.published
                                .by_category(intent.to_s)
                                .by_locale(@ticket.user&.language || 'pt-BR')
                                .ordered
                                .limit(5)

      # If no category match, try search
      if category_faqs.empty?
        category_faqs = SupportFaq.published
                                  .search(@description)
                                  .limit(5)
      end

      category_faqs
    end

    def format_suggestions(faqs)
      faqs.map do |faq|
        {
          id: faq.id,
          slug: faq.slug,
          question: faq.question,
          answer_preview: faq.answer.truncate(200),
          helpful_count: faq.helpful_count,
          relevance_score: calculate_relevance(faq)
        }
      end.sort_by { |s| -s[:relevance_score] }
    end

    def calculate_relevance(faq)
      # Simple relevance scoring
      keyword_matches = faq.keywords.count { |k| @description.include?(k) }
      popularity_score = faq.helpful_count / 10.0

      keyword_matches + popularity_score
    end

    def should_escalate?(confidence, faqs)
      # Escalate if:
      # - Low confidence in intent classification
      # - No relevant FAQs found
      # - High priority ticket
      confidence < CONFIDENCE_THRESHOLD ||
        faqs.empty? ||
        @ticket.priority.in?(%w[high urgent])
    end

    def generate_greeting(intent)
      greetings = {
        riot_integration: "Olá! Parece que você está tendo problemas com a integração Riot. Aqui estão algumas soluções:",
        billing: "Olá! Vi que você tem uma dúvida sobre faturamento. Vamos resolver isso:",
        technical: "Olá! Identificamos um problema técnico. Veja se essas soluções ajudam:",
        features: "Olá! Quer saber como usar um recurso? Confira estas dicas:",
        getting_started: "Olá! Bem-vindo ao ProStaff! Aqui está um guia para começar:",
        other: "Olá! Como posso ajudar? Enquanto isso, veja se estas informações são úteis:"
      }

      greetings[intent] || greetings[:other]
    end
  end
end
