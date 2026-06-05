# Scripts

Scripts de desenvolvimento, segurança e manutenção do ProStaff API.

## Uso rapido

```bash
# Criar usuario de teste (banco fresco)
bundle exec rails runner scripts/create_test_user.rb

# Validar segurança antes de commitar
./scripts/validate-security.sh

# Gerar secrets para .env
./scripts/generate_secrets.sh

# Obter JWT de desenvolvimento
./scripts/get-token.sh

# Testar rate limiting
./scripts/test_rate_limit.sh

# Fix de rede (503 no Traefik)
./scripts/fix_network.sh

# Atualizar diagrama de arquitetura no README
ruby scripts/update_architecture_diagram.rb
```

## Scripts

### `create_test_user.rb`

Cria o usuario de teste (`test@prostaff.gg`) em uma organizacao existente. Requer que a organizacao ja exista no banco.

```bash
bundle exec rails runner scripts/create_test_user.rb
# ou com credenciais customizadas
TEST_EMAIL=outro@email.com TEST_PASSWORD=senha123 bundle exec rails runner scripts/create_test_user.rb
```

### `validate-security.sh`

Roda Semgrep via Docker e exibe apenas erros com severidade ERROR. Retorna exit code 1 se encontrar vulnerabilidades criticas.

```bash
./scripts/validate-security.sh
```

### `generate_secrets.sh`

Gera valores aleatorios para `SECRET_KEY_BASE` e `JWT_SECRET_KEY` via `openssl rand`. Colar no `.env`.

```bash
./scripts/generate_secrets.sh
```

### `get-token.sh`

Faz login com as credenciais de teste e retorna o JWT de acesso. Util para testes rapidos com curl.

```bash
./scripts/get-token.sh
# usa TEST_EMAIL / TEST_PASSWORD do ambiente, com fallback para test@prostaff.gg
```

### `test_rate_limit.sh`

Dispara 100 requisicoes contra `API_URL` para verificar o rate limiting do Traefik (limite: 30 req/s, burst: 50).

```bash
./scripts/test_rate_limit.sh
API_URL=https://staging.prostaff.gg/up ./scripts/test_rate_limit.sh
```

### `fix_network.sh`

Diagnostica e corrige erros 503 causados por desconexao entre o container da API e a rede do Traefik no Coolify.

```bash
./scripts/fix_network.sh
```

### `apply_quick_optimizations.sh`

Aplica indexes de banco de dados e outras otimizacoes de performance via `rails runner`. Para uso em ambientes que nao passaram pelas migrations mais recentes.

```bash
./scripts/apply_quick_optimizations.sh
```

### `update_architecture_diagram.rb`

Introspecta a estrutura do projeto (modulos, models, controllers, services, rotas, dependencias do Gemfile) e atualiza o diagrama Mermaid no `README.md`.

```bash
ruby scripts/update_architecture_diagram.rb
```

Tambem executado automaticamente pelo GitHub Actions a cada push em `master` quando arquivos em `app/modules/`, `app/models/`, `app/controllers/`, `config/routes.rb` ou `Gemfile` sao alterados.
