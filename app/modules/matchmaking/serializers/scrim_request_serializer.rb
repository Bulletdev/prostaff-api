class ScrimRequestSerializer < Blueprinter::Base
  identifier :id

  fields :status, :game, :message, :proposed_at, :expires_at,
         :requesting_scrim_id, :target_scrim_id,
         :created_at, :updated_at

  field :requesting_organization do |req|
    {
      id: req.requesting_organization.id,
      name: req.requesting_organization.name,
      slug: req.requesting_organization.slug,
      region: req.requesting_organization.region
    }
  end

  field :target_organization do |req|
    {
      id: req.target_organization.id,
      name: req.target_organization.name,
      slug: req.target_organization.slug,
      region: req.target_organization.region
    }
  end

  field :pending do |req|
    req.pending?
  end

  field :expired do |req|
    req.expired?
  end
end
