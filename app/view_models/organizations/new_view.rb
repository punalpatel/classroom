# frozen_string_literal: true
module Organizations
  class NewView < ViewModel
    attr_reader :user

    PAGE_SIZE = 24

    # rubocop:disable Metrics/AbcSize
    # rubocop:disable MethodLength
    def github_organizations(page)
      memberships      = organization_memberships(page)
      organization_ids = org_ids(memberships.map { |membership| membership.organization.id })

      Kaminari.paginate_array(
        memberships.map do |membership|
          {
            classroom: organization_ids.include?(membership.organization.id),
            github_id: membership.organization.id,
            login:     membership.organization.login,
            role:      membership.role
          }
        end
      ).page(page).limit(PAGE_SIZE)
    end
    # rubocop:enable MethodLength
    # rubocop:enable Metrics/AbcSize

    private

    def github_user
      @github_user ||= user.github_user
    end

    def org_ids(github_organization_ids)
      Organization.unscoped.where(github_id: github_organization_ids).pluck(:github_id)
    end

    def organization_memberships(page)
      Kaminari.paginate_array(user.github_user.organization_memberships).page(page).limit(PAGE_SIZE)
    end
  end
end
