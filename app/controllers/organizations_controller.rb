# frozen_string_literal: true
class OrganizationsController < ApplicationController
  include OrganizationsHelper

  before_action :authorize_organization_access, except: [:index, :new, :create]
  before_action :add_user_to_organizations,     only: [:index]

  def index
    @organizations = current_user.organizations.page(params[:page])
  end

  def new
    @view ||= Organizations::NewView.new(user: current_user)
  end

  def create
    organization_result = Organization::Creator.perform(
      users: [current_user],
      github_id: new_organization_params['github_id']
    )

    if organization_result.success?
      redirect_to setup_organization_path(organization_result.organization)
    else
      flash[:error] = organization_result.error
      redirect_to new_organization_path
    end
  end

  def show
    @assignments = Kaminari
                   .paginate_array(current_organization.all_assignments(with_invitations: true)
                   .sort_by(&:updated_at))
                   .page(params[:page])
  end

  def edit
  end

  def invitation
  end

  def show_groupings
    ensure_team_management_flipper_is_enabled
    @groupings = current_organization.groupings
  end

  def update
    if current_organization.update_attributes(update_organization_params)
      flash[:success] = "Organization \"#{current_organization.title}\" updated"
      redirect_to current_organization
    else
      render :edit
    end
  end

  def destroy
    if current_organization.update_attributes(deleted_at: Time.zone.now)
      DestroyResourceJob.perform_later(current_organization)

      flash[:success] = "Your organization, @#{current_organization.github_organization.login} is being reset"
      redirect_to organizations_path
    else
      render :edit
    end
  end

  def new_assignment
  end

  def invite
  end

  def setup
  end

  def setup_organization
    organization_result = Organization::Editor.perform(
      organization,
      title: update_organization_params[:title]
    )

    if organization_result.success?
      redirect_to invite_organization_path(current_organization)
    else
      flash[:error] = organization_result.error
      redirect_to :setup
    end
  end

  private

  # TODO: :fire: this thing to the ground.
  # I _loath_ the fact that we do this everytime user comes to the index page
  # rubocop:disable Metrics/AbcSize
  def add_user_to_organizations
    memberships = current_user.github_user.organization_memberships
    user_organization_ids = current_user.organizations.pluck(:github_id)

    memberships.keep_if do |membership|
      !user_organization_ids.include?(membership.organization.id) && membership.role == 'admin'
    end

    github_organization_ids = memberships.map { |membership| membership.organization.id }

    Organization.unscoped.select(:id).where(github_id: github_organization_ids).each do |organization|
      Organization::Editor.add_users(organization, [current_user])
    end
  end
  # rubocop:enable Metrics/AbcSize

  def new_organization_params
    params.require(:organization).permit(:github_id)
  end

  def update_organization_params
    params.require(:organization).permit(:title)
  end
end
