# frozen_string_literal: true

# Concern para aplicar scoping automático de organização
# Como o RLS do PostgreSQL não funciona com o usuário owner (postgres),
# implementamos o scoping no nível da aplicação Rails usando CurrentAttributes
module OrganizationScoped
  extend ActiveSupport::Concern

  included do
    # Aplicar default_scope apenas se houver uma organização no contexto
    default_scope lambda {
      org_id = Current.organization_id
      if org_id.present?
        where(organization_id: org_id)
      elsif Current.skip_organization_scope
        all
      else
        # SECURITY: Fail-safe - retorna scope vazio em vez de expor dados de todas as orgs
        Rails.logger.error("[SECURITY] OrganizationScoped: organization_id is nil for #{name} - BLOCKING ACCESS")
        where('1=0')
      end
    }
  end

  class_methods do
    # Método para bypassar o scope quando necessário (ex: seeds, migrations)
    def unscoped_by_organization
      unscoped
    end
  end
end
