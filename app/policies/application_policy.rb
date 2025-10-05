class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  private

  def owner?
    user.role == 'owner'
  end

  def admin?
    user.role == 'admin' || user.role == 'owner'
  end

  def coach?
    %w[coach admin owner].include?(user.role)
  end

  def analyst?
    %w[analyst coach admin owner].include?(user.role)
  end

  def same_organization?
    record.respond_to?(:organization_id) && record.organization_id == user.organization_id
  end
end
