# frozen_string_literal: true
class Organization
  class Creator
    attr_reader :users, :github_id

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

    # Public: Create an Organization.
    #
    # users     - An Array of Users that will own the organization.
    # github_id - The Integer GitHub id.
    #
    # Returns an Organization::Creator::Result.
    def self.perform(users:, github_id:)
      new(users: users, github_id: github_id).perform
    end

    def initialize(users:, github_id:)
      @users     = users
      @github_id = github_id.to_i
    end

    def perform
      ensure_users_are_authorized!
      organization = Organization.new

      Organization.transaction do
        organization.tap do |org|
          org.users     = users
          org.github_id = github_id
          org.title     = title
        end

        create_organization_webhook!(organization)
        organization.save!
      end

      Result.success(organization)
    rescue StandardError => e
      silently_destroy_organization_webhook(organization)
      Result.failed e.message
    end

    private

    def create_organization_webhook!(organization)
      webhook = github_organization.create_organization_webhook(config: { url: webhook_url })
      organization.webhook_id = webhook.id
    end

    def ensure_users_are_authorized!
      users.each do |user|
        next if github_organization(user.github_client).admin?(user.github_user.login)
        raise NotAuthorized, 'You are not permitted to add this organization as a classroom'
      end
    end

    def github_organization(github_client = nil)
      github_client ||= users.sample.github_client
      GitHubOrganization.new(github_client, github_id)
    end

    def silently_destroy_organization_webhook
      github_organization.remove_organization_webhook(webhook_id)
      true
    end

    def title
      github_organization.name.present? ? github_organization.name : github_organization.login
    end

    def webhook_url
      uri = if Rails.env.production?
              'https://classroom.github.com'
            else
              'http://localhost:5000'
            end

      "#{uri}/hooks"
    end
  end
end
