# frozen_string_literal: true
class Organization
  class Editor
    attr_reader :organization, :users, :title

    class Result
      class Error < StandardError; end

      def self.success(organization)
        new(:success, organization: organization)
      end

      def self.failed(error)
        new(:failed, error: error)
      end

      attr_reader :error, :organization

      def initialize(status, organization: nil, error: nil)
        @status       = status
        @organization = organization
        @error        = error
      end

      def success?
        @status == :success
      end

      def failed?
        @status == :failed
      end
    end

    # Public: Edit an Organization
    #
    # organization  - The Organization being edited.
    # users:        - An Array of Users that own the organization (optional).
    # title:        - The String title (optional).
    #
    # Returns an Organization::Editor::Result.
    def self.perform(organization, users: nil, title: nil)
      new(organization, users: users, title: title).perform
    end

    # Public: Add Users to an Organization
    #
    # organization  - The Organization being edited.
    # users:        - An Array of Users to add to the organization.
    #
    # Returns an Organization::Editor::Result.
    def self.add_users(organization, users:)
      new(organization, users: users, title: nil).add_users
    end

    # Public: Remove Users from an Organization
    #
    # organization  - The Organization being edited.
    # users:        - An Array of Users to remove from the organization.
    #
    # Returns an Organization::Editor::Result.
    def self.remove_users(organization, users:)
      new(organization, users: users, title: nil).remove_users
    end

    def initialize(organization, users:, title:)
      @organization = organization
      @users        = users
      @title        = title
    end

    def perform
      organization_params = {}.tap do |opts|
        opts[:users] = users if users.present?
        opts[:title] = title if title.present?
      end

      organization.update_attributes!(organization_params)

      Result.success(organization)
    rescue Result::Error => e
      Result.failed e.message
    end

    def add_users
      users.each do |user|
        organization.users << user
      end
    end

    def remove_users
      organization.users.delete(*users)
    rescue Result::Error => e
      Result.failed e.message
    end

    private

    def github_organization(github_client = nil)
      github_client ||= users.sample.github_client
      GitHubOrganization.new(github_client, github_id)
    end
  end
end
