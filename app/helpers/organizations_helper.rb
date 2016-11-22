# frozen_string_literal: true
module OrganizationsHelper
  def self.included(base)
    return unless base.respond_to?(:helper_method)
    base.helper_method :current_organization
  end

  def authorize_organization_access
    current_organization.admin?(current_user)
  end

  def current_organization
    return @organization if defined?(@organization)
    id = params[:organization_id] || params[:id]
    @organization = Organization.find_by!(slug: id)
  end
end
