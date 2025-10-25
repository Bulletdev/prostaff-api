# 🔒 Player Import Security - Proteção contra Importação Duplicada

## Visão Geral

O sistema implementa uma proteção rigorosa contra a importação de jogadores que já pertencem a outras organizações. Esta é uma medida de segurança importante para:

1. **Prevenir conflitos de dados** - Um jogador só pode estar ativo em uma organização por vez
2. **Proteger a privacidade** - Evitar que organizações vejam/importem jogadores de competidores
3. **Compliance** - Registrar tentativas suspeitas para auditoria

## Como Funciona

### Validação no Import

Quando uma organização tenta importar um jogador:

1. ✅ Sistema busca o jogador na Riot API
2. ✅ Verifica se o `riot_puuid` já existe no banco de dados
3. ✅ Se existir em **outra organização**, bloqueia a importação
4. ✅ Registra a tentativa no `AuditLog` para auditoria
5. ✅ Retorna erro **403 Forbidden** com mensagem clara

### Mensagem de Erro

```
This player is already registered in another organization.
Players can only be associated with one organization at a time.
Attempting to import players from other organizations may result
in account restrictions.
```

### Status HTTP

- **403 Forbidden** - Jogador pertence a outra organização
- **404 Not Found** - Jogador não encontrado na Riot API
- **422 Unprocessable Entity** - Formato inválido de Riot ID

## Logs de Auditoria

Cada tentativa bloqueada gera um registro em `audit_logs` com:

```ruby
{
  organization: <organização que tentou importar>,
  action: 'import_attempt_blocked',
  entity_type: 'Player',
  entity_id: <id do player existente>,
  new_values: {
    attempted_summoner_name: "PlayerName#TAG",
    actual_summoner_name: "PlayerName#TAG",
    owner_organization_id: "uuid",
    owner_organization_name: "Org Name",
    reason: "Player already belongs to another organization",
    puuid: "riot_puuid"
  }
}
```

## Logs de Sistema

Tentativas bloqueadas também geram logs de WARNING:

```
⚠️  SECURITY: Attempt to import player <name> (PUUID: <puuid>)
that belongs to organization <org_name> by organization <attempting_org>
```

## Código de Erro

```ruby
code: 'PLAYER_BELONGS_TO_OTHER_ORGANIZATION'
```

## Exemplo de Uso

### Request (Frontend)
```javascript
await playersService.importFromRiot({
  summoner_name: "PlayerName#TAG",
  role: "mid"
});
```

### Response (Erro - Jogador já existe)
```json
{
  "error": {
    "code": "PLAYER_BELONGS_TO_OTHER_ORGANIZATION",
    "message": "This player is already registered in another organization. Players can only be associated with one organization at a time. Attempting to import players from other organizations may result in account restrictions.",
    "status": 403
  }
}
```

## Implicações para Compliance

- ✅ Todas as tentativas são registradas com timestamp
- ✅ Informações da organização que tentou são armazenadas
- ✅ PUUID do jogador é registrado para rastreamento
- ✅ Logs podem ser usados para identificar padrões suspeitos

## Notas Importantes

1. **Unicidade Global**: O `riot_puuid` é único globalmente, não por organização
2. **Auditoria Completa**: Todas as tentativas são registradas, mesmo as bloqueadas
3. **Privacidade**: O sistema NÃO revela qual organização possui o jogador (apenas registra internamente)
4. **Ações Futuras**: Tentativas repetidas podem resultar em bloqueio de conta (a implementar)

## Implementação Técnica

### Arquivos Modificados

1. `app/modules/players/services/riot_sync_service.rb:73-97`
   - Validação antes de criar o player
   - Log de segurança
   - Criação de audit log

2. `app/modules/players/controllers/players_controller.rb:357-358`
   - Mapeamento de código de erro para status HTTP 403

## Próximos Passos Sugeridos

- [ ] Implementar rate limiting para tentativas de import
- [ ] Alertas para administradores após X tentativas bloqueadas
- [ ] Dashboard de segurança mostrando tentativas suspeitas
- [ ] Bloqueio temporário de conta após múltiplas tentativas

---

**Última atualização**: 2025-10-25
**Versão**: 1.0.0
