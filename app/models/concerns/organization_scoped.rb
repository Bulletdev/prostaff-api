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
      else
        Rails.logger.warn("[SCOPE] OrganizationScoped: Current.organization_id is nil for #{name}")
        all
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
