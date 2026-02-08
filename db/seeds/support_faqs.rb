# frozen_string_literal: true

puts "🌱 Seeding Support FAQs..."

faqs = [
  # Getting Started
  {
    question: "Como começar a usar o ProStaff?",
    answer: <<~ANSWER,
      Para começar a usar o ProStaff:

      1. **Cadastre sua organização**: Vá em Settings > Organization e preencha os dados da sua equipe
      2. **Adicione jogadores**: Em Players > Add Player, adicione os summoner names dos seus jogadores
      3. **Conecte com Riot API**: Em Settings > Riot Integration, adicione sua API key da Riot Games
      4. **Importe partidas**: Vá em Matches > Import e comece a importar os jogos dos seus jogadores

      Precisa de ajuda? Entre em contato com nosso suporte!
    ANSWER
    category: "getting_started",
    keywords: ["começar", "iniciar", "primeiro passo", "setup", "configurar"],
    position: 1
  },
  {
    question: "Como adicionar jogadores ao meu time?",
    answer: <<~ANSWER,
      Para adicionar jogadores:

      1. Vá em **Players** no menu lateral
      2. Clique em **Add Player**
      3. Preencha os dados:
         - Summoner Name (obrigatório)
         - Nome Real
         - Role (Top, Jungle, Mid, ADC, Support)
         - Status (Active, Inactive, Benched, etc)
      4. Clique em **Save**

      O sistema irá buscar automaticamente os dados do jogador na Riot API!
    ANSWER
    category: "getting_started",
    keywords: ["adicionar", "jogador", "player", "time", "roster"],
    position: 2
  },

  # Riot Integration
  {
    question: "Como importar partidas da Riot API?",
    answer: <<~ANSWER,
      Para importar partidas:

      1. Vá em **Matches** > **Import Matches**
      2. Selecione o jogador
      3. O sistema buscará automaticamente as partidas recentes
      4. Clique em **Import** para importar as partidas

      **Importante**: Você precisa ter configurado sua Riot API Key em Settings > Riot Integration.

      As partidas serão processadas em background e aparecerão em alguns minutos.
    ANSWER
    category: "riot_integration",
    keywords: ["importar", "import", "match", "partida", "riot", "api"],
    position: 1
  },
  {
    question: "Erro 403 ao sincronizar com Riot API",
    answer: <<~ANSWER,
      O erro 403 (Forbidden) geralmente indica problema com a API Key. Verifique:

      1. **API Key válida**: Vá em Settings > Riot Integration e verifique se sua API key está correta
      2. **API Key expirada**: API keys de desenvolvimento expiram após 24h. Gere uma nova em https://developer.riotgames.com
      3. **Região correta**: Certifique-se de que está usando a região correta (BR1 para Brasil)

      **Solução**:
      1. Acesse https://developer.riotgames.com
      2. Faça login com sua conta Riot
      3. Gere uma nova Development API Key
      4. Cole a nova key em Settings > Riot Integration
      5. Tente importar novamente

      Se o problema persistir, entre em contato com o suporte.
    ANSWER
    category: "riot_integration",
    keywords: ["403", "forbidden", "api key", "erro", "sync", "sincronizar"],
    position: 2
  },
  {
    question: "Erro 429 - Rate Limit Exceeded",
    answer: <<~ANSWER,
      O erro 429 significa que você excedeu o limite de requisições da Riot API.

      **Limites da API**:
      - Development Key: 20 requisições/segundo, 100 requisições/2 minutos
      - Production Key: Limites maiores

      **Soluções**:
      1. **Aguarde alguns minutos** antes de tentar novamente
      2. **Importe menos partidas por vez** (5-10 partidas)
      3. **Solicite Production API Key** se você importa muitas partidas frequentemente

      O ProStaff já tem rate limiting automático, mas em picos de uso pode acontecer.
    ANSWER
    category: "riot_integration",
    keywords: ["429", "rate limit", "too many requests", "limite"],
    position: 3
  },
  {
    question: "Match ID não encontrado (404)",
    answer: <<~ANSWER,
      Se você está recebendo erro 404 ao importar uma partida:

      **Causas comuns**:
      1. Match ID incorreto ou com formato errado
      2. Partida muito antiga (Riot API só mantém histórico recente)
      3. Região errada (ex: tentando importar match BR1_ com região NA1)

      **Solução**:
      1. Verifique o formato do Match ID: `BR1_1234567890`
      2. Certifique-se de que a região está correta
      3. Partidas com mais de 2 anos podem não estar disponíveis

      **Dica**: Use a importação automática em vez de manual - o sistema busca automaticamente as partidas recentes do jogador.
    ANSWER
    category: "riot_integration",
    keywords: ["404", "not found", "match id", "partida não encontrada"],
    position: 4
  },

  # Billing
  {
    question: "Como fazer upgrade do meu plano?",
    answer: <<~ANSWER,
      Para fazer upgrade do plano:

      1. Vá em **Organization** > **Subscription**
      2. Veja os planos disponíveis:
         - **Starter**: Até 10 jogadores, recursos básicos
         - **Professional**: Até 50 jogadores, analytics avançado
         - **Enterprise**: Ilimitado, suporte prioritário
      3. Clique em **Upgrade** no plano desejado
      4. Preencha os dados de pagamento
      5. Confirme a assinatura

      O upgrade é aplicado imediatamente!
    ANSWER
    category: "billing",
    keywords: ["upgrade", "plano", "assinatura", "subscription", "pagar"],
    position: 1
  },
  {
    question: "Quais são as formas de pagamento aceitas?",
    answer: <<~ANSWER,
      Aceitamos as seguintes formas de pagamento:

      **Cartão de Crédito**:
      - Visa, Mastercard, American Express
      - Cobrança mensal ou anual
      - Desconto de 20% no plano anual

      **PIX** (apenas Brasil):
      - Pagamento único anual
      - Aprovação instantânea

      **Boleto Bancário**:
      - Disponível para planos anuais
      - Vencimento em 3 dias úteis

      Para empresas, oferecemos também pagamento via transferência bancária (mínimo 10 licenças).
    ANSWER
    category: "billing",
    keywords: ["pagamento", "cartão", "pix", "boleto", "payment"],
    position: 2
  },

  # Features
  {
    question: "Como usar o sistema de VOD Review?",
    answer: <<~ANSWER,
      O VOD Review permite analisar partidas em vídeo:

      1. Vá em **VOD Reviews** > **New Review**
      2. Selecione a partida que quer revisar
      3. Cole o link do VOD (YouTube, Twitch, etc)
      4. Adicione timestamps e comentários:
         - Clique em **Add Timestamp**
         - Defina o momento (ex: 15:30)
         - Adicione sua análise
      5. Marque jogadores relevantes (@menção)
      6. Salve a review

      Os jogadores receberão notificação e podem comentar!
    ANSWER
    category: "features",
    keywords: ["vod", "review", "análise", "partida", "vídeo"],
    position: 1
  },
  {
    question: "Como funciona o sistema de Scouting?",
    answer: <<~ANSWER,
      O Scouting permite acompanhar jogadores que você quer recrutar:

      1. Vá em **Scouting** > **Add Target**
      2. Busque o jogador pelo summoner name
      3. Adicione notas sobre o jogador:
         - Pontos fortes
         - Pontos a melhorar
         - Interesse (Alto, Médio, Baixo)
      4. O sistema rastreia automaticamente:
         - Performance recente
         - KDA e winrate
         - Champion pool
         - Rank atual

      Você receberá alertas quando o jogador tiver mudanças significativas!
    ANSWER
    category: "features",
    keywords: ["scouting", "recrutar", "jogador", "target", "scout"],
    position: 2
  },

  # Technical
  {
    question: "O dashboard não está carregando",
    answer: <<~ANSWER,
      Se o dashboard não carregar:

      **Soluções rápidas**:
      1. **Limpe o cache** do navegador (Ctrl+Shift+Del)
      2. **Atualize a página** (Ctrl+R ou F5)
      3. **Faça logout e login** novamente
      4. **Tente outro navegador** (Chrome, Firefox, Edge)

      **Ainda não funciona?**
      1. Verifique sua conexão com internet
      2. Desabilite extensões do navegador (AdBlock, etc)
      3. Limpe cookies do site
      4. Entre em contato com o suporte com:
         - Navegador e versão
         - Sistema operacional
         - Screenshot do erro (se houver)

      Nosso suporte responde em menos de 2 horas!
    ANSWER
    category: "technical",
    keywords: ["dashboard", "não carrega", "loading", "erro", "bug"],
    position: 1
  },
  {
    question: "Como reportar um bug?",
    answer: <<~ANSWER,
      Para reportar um bug:

      1. Vá em **Support** > **Open Ticket**
      2. Selecione categoria: **Technical Issue**
      3. Descreva o problema com detalhes:
         - O que você estava fazendo?
         - O que aconteceu?
         - O que deveria acontecer?
      4. Anexe:
         - Screenshot do erro
         - Console do navegador (F12 > Console)
      5. Envie o ticket

      Nossa equipe irá investigar e responder em até 4 horas (tickets urgentes em 1 hora).

      **Dica**: Se possível, tente reproduzir o erro e anote os passos!
    ANSWER
    category: "technical",
    keywords: ["bug", "erro", "reportar", "problema", "issue"],
    position: 2
  }
]

created_count = 0
updated_count = 0

faqs.each do |faq_data|
  slug = faq_data[:question].parameterize

  faq = SupportFaq.find_or_initialize_by(slug: slug)

  if faq.new_record?
    faq.assign_attributes(faq_data.merge(locale: 'pt-BR', published: true))
    faq.save!
    created_count += 1
    puts "  ✅ Created: #{faq.question.truncate(60)}"
  else
    faq.update!(faq_data)
    updated_count += 1
    puts "  🔄 Updated: #{faq.question.truncate(60)}"
  end
end

puts ""
puts "✅ FAQ Seeding Complete!"
puts "   Created: #{created_count} FAQs"
puts "   Updated: #{updated_count} FAQs"
puts "   Total: #{SupportFaq.count} FAQs in database"
