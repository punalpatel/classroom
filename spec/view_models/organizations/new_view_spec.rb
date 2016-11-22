# frozen_string_literal: true
require 'rails_helper'

RSpec.describe Organizations::NewView do
  let(:user) { GitHubFactory.create_owner_classroom_org.users.first }

  subject { Organizations::NewView.new(user: user) }

  it 'has a PAGE_SIZE of 24' do
    expect(Organizations::NewView::PAGE_SIZE).to eql(24)
  end

  it 'responds to :user' do
    expect(subject).to respond_to(:user)
  end

  it 'returns an Kaminari paginated array of orgniazation memberships', :vcr do
    organizations = subject.github_organizations(0)
    expect(organizations).to be_a(Kaminari::PaginatableArray)
  end
end
