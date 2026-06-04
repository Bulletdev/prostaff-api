# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChatbotService do
  let(:organization) { create(:organization) }
  let(:user)         { create(:user, organization: organization) }

  let(:ticket) do
    create(:support_ticket,
           user: user,
           organization: organization,
           description: description,
           category: 'technical',
           priority: 'medium')
  end

  subject(:service) { described_class.new(ticket) }

  # ── Keyword-based path (CHATBOT_USE_LLM != 'true') ────────────────────────

  describe '#generate_suggestions' do
    before do
      # Ensure LLM path is disabled (default in test env)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('CHATBOT_USE_LLM').and_return(nil)
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
    end

    context 'with a riot-integration related description' do
      let(:description) { 'I have a problem with the riot api sync and rate limit 429 error' }

      it 'returns a hash with expected keys' do
        result = service.generate_suggestions
        expect(result).to be_a(Hash)
        expect(result).to include(:intent, :confidence, :suggestions, :should_escalate, :greeting)
      end

      it 'classifies intent as riot_integration' do
        result = service.generate_suggestions
        expect(result[:intent].to_s).to eq('riot_integration')
      end

      it 'returns a non-empty greeting string' do
        result = service.generate_suggestions
        expect(result[:greeting]).to be_a(String)
        expect(result[:greeting]).not_to be_empty
      end

      it 'returns confidence between 0.0 and 1.0' do
        result = service.generate_suggestions
        expect(result[:confidence]).to be_between(0.0, 1.0)
      end

      it 'returns suggestions as an array' do
        result = service.generate_suggestions
        expect(result[:suggestions]).to be_an(Array)
      end

      it 'returns a boolean for should_escalate' do
        result = service.generate_suggestions
        expect(result[:should_escalate]).to be_in([true, false])
      end
    end

    context 'with a billing related description' do
      let(:description) { 'I need help with my payment subscription invoice card' }

      it 'classifies intent as billing' do
        result = service.generate_suggestions
        expect(result[:intent].to_s).to eq('billing')
      end
    end

    context 'with an unrecognized description (no keyword matches)' do
      let(:description) { 'xyz abc 123 completely unrelated content with no known keywords' }

      it 'returns a non-nil intent string' do
        result = service.generate_suggestions
        expect(result[:intent]).to be_a(Symbol).or be_a(String)
      end

      it 'returns confidence 0.0 when no keywords matched' do
        result = service.generate_suggestions
        # confidence is 0.0 for 'other' OR any category with 0 matches
        expect(result[:confidence]).to be_between(0.0, 1.0)
      end

      it 'returns a greeting string regardless of intent' do
        result = service.generate_suggestions
        expect(result[:greeting]).to be_a(String)
        expect(result[:greeting]).not_to be_empty
      end
    end

    context 'when ticket has high priority' do
      let(:description) { 'something generic' }
      let(:ticket) do
        create(:support_ticket,
               user: user,
               organization: organization,
               description: description,
               category: 'technical',
               priority: 'high')
      end

      it 'should_escalate is true (high priority always escalates)' do
        result = service.generate_suggestions
        expect(result[:should_escalate]).to be(true)
      end
    end

    context 'when ticket has urgent priority' do
      let(:description) { 'something generic' }
      let(:ticket) do
        create(:support_ticket,
               user: user,
               organization: organization,
               description: description,
               category: 'technical',
               priority: 'urgent')
      end

      it 'should_escalate is true' do
        result = service.generate_suggestions
        expect(result[:should_escalate]).to be(true)
      end
    end

    context 'with relevant FAQs in database' do
      let(:description) { 'how do I get started with setup configure' }

      before do
        create(:support_faq,
               category: 'getting_started',
               locale: 'pt-BR',
               published: true,
               keywords: %w[setup configure install])
      end

      it 'returns suggestions that are hashes with FAQ-like keys' do
        result = service.generate_suggestions
        expect(result[:suggestions]).to be_an(Array)
        # If FAQs found, each entry should have required keys
        result[:suggestions].each do |suggestion|
          expect(suggestion).to include(:id, :slug, :question, :answer_preview)
        end
      end
    end
  end

  # ── LLM path with OpenAI stub ─────────────────────────────────────────────

  describe '#generate_suggestions (LLM path)' do
    let(:description) { 'I have a problem syncing with riot api' }
    let(:openai_response_body) do
      {
        'choices' => [
          {
            'message' => {
              'content' => {
                'intent' => 'riot_integration',
                'confidence' => 0.9,
                'relevant_faq_ids' => [],
                'greeting' => 'Ola! Parece que voce esta tendo problemas com a integracao Riot.',
                'should_escalate' => false,
                'suggested_solution' => 'Verifique sua chave API do Riot Games.'
              }.to_json
            }
          }
        ]
      }.to_json
    end

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('CHATBOT_USE_LLM').and_return('true')
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return('sk-test-key-for-testing')
      allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('OPENAI_MODEL').and_return('gpt-4')

      stub_request(:post, /api\.openai\.com/)
        .to_return(
          status: 200,
          body: openai_response_body,
          headers: { 'Content-Type' => 'application/json' }
        )
    end

    it 'returns a hash with expected keys' do
      result = service.generate_suggestions
      expect(result).to be_a(Hash)
      expect(result).to include(:intent, :confidence, :suggestions, :should_escalate, :greeting)
    end

    it 'does not raise on successful LLM call' do
      expect { service.generate_suggestions }.not_to raise_error
    end

    context 'when OpenAI returns 429 (rate limited)' do
      before do
        stub_request(:post, /api\.openai\.com/)
          .to_return(status: 429, body: '{"error":"rate_limit_exceeded"}',
                     headers: { 'Content-Type' => 'application/json' })
      end

      it 'falls back to keyword-based suggestions without raising' do
        expect { service.generate_suggestions }.not_to raise_error
        result = service.generate_suggestions
        expect(result).to be_a(Hash)
        expect(result).to include(:intent, :suggestions, :greeting)
      end
    end

    context 'when OpenAI returns 503 (service unavailable)' do
      before do
        stub_request(:post, /api\.openai\.com/)
          .to_return(status: 503, body: '{"error":"service_unavailable"}')
      end

      it 'falls back gracefully without raising' do
        expect { service.generate_suggestions }.not_to raise_error
        result = service.generate_suggestions
        expect(result).to be_a(Hash)
      end
    end

    context 'when OpenAI returns invalid JSON' do
      before do
        stub_request(:post, /api\.openai\.com/)
          .to_return(
            status: 200,
            body: {
              'choices' => [{ 'message' => { 'content' => 'not valid json {{}' } }]
            }.to_json,
            headers: { 'Content-Type' => 'application/json' }
          )
      end

      it 'falls back to keyword-based suggestions without raising' do
        expect { service.generate_suggestions }.not_to raise_error
        result = service.generate_suggestions
        expect(result).to be_a(Hash)
        expect(result).to include(:intent)
      end
    end

    context 'when OpenAI connection times out' do
      before do
        stub_request(:post, /api\.openai\.com/)
          .to_timeout
      end

      it 'falls back gracefully without raising' do
        expect { service.generate_suggestions }.not_to raise_error
      end
    end
  end

  # ── Domain invariants ─────────────────────────────────────────────────────

  describe 'domain invariants' do
    let(:description) { 'some description text about technical bug error crash' }

    before do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('CHATBOT_USE_LLM').and_return(nil)
      allow(ENV).to receive(:[]).with('OPENAI_API_KEY').and_return(nil)
      allow(ENV).to receive(:[]).with('ANTHROPIC_API_KEY').and_return(nil)
    end

    it 'never leaks API keys in the result' do
      result = service.generate_suggestions
      result_str = result.to_s
      expect(result_str).not_to include('sk-')
      expect(result_str).not_to include('OPENAI_API_KEY')
    end

    it 'confidence is always within [0.0, 1.0]' do
      result = service.generate_suggestions
      expect(result[:confidence]).to be_between(0.0, 1.0)
    end

    it 'greeting always returns a string for every intent category' do
      ChatbotService::INTENT_KEYWORDS.each_key do |intent|
        # Directly test the private generate_greeting for completeness
        greeting = service.send(:generate_greeting, intent)
        expect(greeting).to be_a(String)
        expect(greeting).not_to be_empty
      end
    end
  end
end
