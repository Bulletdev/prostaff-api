# Branch Protection Ruleset - Master Branch

Este documento explica as regras de proteção configuradas para a branch `master` do ProStaff API.

## Regras Configuradas

### 1. **Pull Request Reviews** 
- **Aprovações necessárias**: 1 reviewer
- **Dismiss stale reviews**: Reviews antigas são descartadas quando novo código é pushed
- **Thread resolution**: Todos os comentários devem ser resolvidos antes do merge

**Por quê?** Garante revisão de código e discussão de qualidade antes das mudanças irem para produção.

### 2. **Required Status Checks** 
- **Security Scan**: Workflow obrigatório que deve passar
  - Brakeman (análise estática de segurança)
  - Dependency check (vulnerabilidades em gems)
- **Strict mode**: Branch deve estar atualizada com master antes do merge

**Por quê?** Garante que nenhum código com vulnerabilidades de segurança seja mergeado.

### 3. **Linear History** 
- Apenas fast-forward merges ou squash merges permitidos
- Histórico de commits limpo e linear

**Por quê?** Facilita navegação no histórico e rollbacks se necessário.

### 4. **Required Signatures** 
- Commits devem ser assinados com GPG
- Garante autenticidade do autor

**Por quê?** Segurança adicional contra commits não autorizados.

### 5. **Deletion Protection** 
- Branch master não pode ser deletada

**Por quê?** Proteção contra acidentes catastróficos.

### 6. **Force Push Protection** 
- Force pushes não são permitidos
- Histórico não pode ser reescrito

**Por quê?** Preserva integridade do histórico compartilhado.

### 7. **Creation Protection** 
- Apenas administradores podem criar a branch master

**Por quê?** Controle total sobre a branch principal.


##  Workflow para Desenvolvedores

### Fluxo de trabalho padrão:

1. **Criar feature branch**
   ```bash
   git checkout -b feature/PS-12345-new-feature
   ```

2. **Fazer commits assinados**
   ```bash
   git commit -S -m "feat: add new feature"
   ```

3. **Push para origin**
   ```bash
   git push origin feature/PS-123-new-feature
   ```

4. **Criar Pull Request**
   - Aguardar Security Scan passar
   - Solicitar review de pelo menos 1 pessoa
   - Resolver todos os comentários

5. **Atualizar branch se necessário**
   ```bash
   git checkout master
   git pull
   git checkout feature/PS-123-new-feature
   git rebase master
   git push --force-with-lease
   ```

6. **Merge após aprovação**
   - Use "Squash and merge" ou "Rebase and merge"
   - Evite "Merge commit" para manter histórico linear

##  Configuração de Commits Assinados

### Gerar chave GPG:

```bash
# Gerar chave
gpg --full-generate-key

# Listar chaves
gpg --list-secret-keys --keyid-format=long

# Exportar chave pública
gpg --armor --export YOUR_KEY_ID

# Adicionar ao GitHub
# Settings → SSH and GPG keys → New GPG key
```

### Configurar Git:

```bash
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true
git config --global gpg.program gpg
```

## 🚨 Troubleshooting

### Security Scan falhando
```bash
# Rodar localmente antes do push
./security_tests/scripts/brakeman-scan.sh
bundle audit check --update
```

### Branch desatualizada
```bash
git fetch origin
git rebase origin/master
```

### Commit não assinado
```bash
# Assinar último commit
git commit --amend --no-edit -S

# Push forçado (apenas em feature branches!)
git push --force-with-lease
```

##  Status Checks Configurados

| Check | Descrição | Timeout |
|-------|-----------|---------|
| Security Scan | Brakeman + bundle audit | ~5min |

### Futuras Status Checks (Recomendadas):

Adicione estas ao ruleset conforme necessário:

```json
{
  "context": "RSpec Tests",
  "integration_id": null
},
{
  "context": "Rubocop",
  "integration_id": null
},
{
  "context": "Load Tests",
  "integration_id": null
}
```

## 🔄 Manutenção

### Revisar regras trimestralmente
- Avaliar se as regras estão muito restritivas ou permissivas
- Adicionar novos status checks conforme o projeto evolui
- Revisar lista de bypass actors

### Métricas para monitorar
- Tempo médio de merge de PRs
- Taxa de PRs bloqueados por security scan
- Número de force pushes tentados (e bloqueados)

##  Exceções

### Quando bypassar regras?

**NUNCA**, exceto em emergências críticas de produção.

Para emergências:
1. Adicione temporariamente um bypass actor
2. Faça a correção
3. Remova o bypass imediatamente
4. Crie um post-mortem documentando o ocorrido

## 📚 Referências

- [GitHub Rulesets Documentation](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-rulesets/about-rulesets)
- [GPG Signing Guide](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits)
- [ProStaff Security Guide](security_tests/README.md)

---

**Última atualização**: 2025-10-13
**Versão do ruleset**: 1.0.0
