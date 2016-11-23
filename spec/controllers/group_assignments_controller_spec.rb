# frozen_string_literal: true
require 'rails_helper'

RSpec.describe GroupAssignmentsController, type: :controller do
  include ActiveJob::TestHelper

  let(:organization) { GitHubFactory.create_owner_classroom_org }
  let(:user)         { organization.users.first                 }

  let(:group_assignment) do
    GroupAssignment.create(attributes_for(:group_assignment).merge(organization: organization, creator: user))
  end

  let(:student_identifier_type) { create(:student_identifier_type, organization: organization) }

  before do
    sign_in(user)
  end

  describe 'GET #new', :vcr do
    it 'returns success status' do
      get :new, params: { organization_id: organization.slug }
      expect(response).to have_http_status(:success)
    end

    it 'has a new GroupAssignment' do
      get :new, params: { organization_id: organization.slug }
      expect(assigns(:group_assignment)).to_not be_nil
    end
  end

  describe 'POST #create', :vcr do
    before do
      request.env['HTTP_REFERER'] = "http://classroomtest.com/organizations/#{organization.slug}/group-assignments/new"
    end

    it 'creates a new GroupAssignment' do
      expect do
        post :create, params: {
          organization_id: organization.slug,
          group_assignment: { title: 'Learn JavaScript', slug: 'learn-javascript' },
          grouping:         { title: 'Grouping 1' }
        }
      end.to change { GroupAssignment.count }
    end

    it 'does not allow groupings to be added that do not belong to the organization' do
      other_group_assignment = create(:group_assignment)

      expect do
        post :create, params: {
          organization_id: organization.slug,
          group_assignment: { title: 'Learn Ruby', grouping_id: other_group_assignment.grouping_id }
        }
      end.not_to change { GroupAssignment.count }
    end

    context 'flipper is enabled for the user' do
      before do
        GitHubClassroom.flipper[:student_identifier].enable
        post :create, params: {
          organization_id:         organization.slug,
          group_assignment:        { title: 'Learn JavaScript', slug: 'learn-javascript' },
          grouping:                { title: 'Grouping 1' },
          student_identifier_type: { id: student_identifier_type.id }
        }
      end

      it 'creates a new Assignment' do
        expect(GroupAssignment.count).to eql(1)
      end

      it 'sets correct student identifier type for the new Assignment' do
        expect(GroupAssignment.first.student_identifier_type.id).to eql(student_identifier_type.id)
      end

      after do
        GitHubClassroom.flipper[:student_identifier].disable
      end
    end
  end

  describe 'GET #show', :vcr do
    it 'returns success status' do
      get :show, params: { organization_id: organization.slug, id: group_assignment.slug }
      expect(response).to have_http_status(:success)
    end
  end

  describe 'GET #edit', :vcr do
    it 'returns success status and sets the group assignment' do
      get :edit, params: { organization_id: organization.slug, id: group_assignment.slug }

      expect(response).to have_http_status(:success)
      expect(assigns(:group_assignment)).to_not be_nil
    end
  end

  describe 'PATCH #update', :vcr do
    it 'correctly updates the assignment' do
      options = { title: 'JavaScript Calculator' }
      patch :update, params: {
        id:               group_assignment.slug,
        organization_id:  organization.slug,
        group_assignment: options
      }

      expect(response).to redirect_to(organization_group_assignment_path(organization,
                                                                         GroupAssignment.find(group_assignment.id)))
    end

    it 'calls the AssignmentVisibility background job' do
      options = { title: 'JavaScript Calculator' }
      patch :update, params: {
        id:               group_assignment.slug,
        organization_id:  organization.slug,
        group_assignment: options
      }

      assert_enqueued_jobs 1 do
        AssignmentVisibilityJob.perform_later(group_assignment)
      end
    end

    context 'slug is empty' do
      it 'correctly reloads the assignment' do
        options = { slug: '' }
        patch :update, params: {
          id:               group_assignment.slug,
          organization_id:  organization.slug,
          group_assignment: options
        }

        expect(assigns(:group_assignment).slug).to_not be_nil
      end
    end

    context 'flipper is enabled for the user' do
      before do
        GitHubClassroom.flipper[:student_identifier].enable
        options = { title: 'JavaScript Calculator' }
        patch :update, params: {
          id:                      group_assignment.slug,
          organization_id:         organization.slug,
          group_assignment:        options,
          student_identifier_type: { id: student_identifier_type.id }
        }
      end

      it 'correctly updates the assignment' do
        expect(GroupAssignment.first.student_identifier_type.id).to eql(student_identifier_type.id)
      end

      after do
        GitHubClassroom.flipper[:student_identifier].disable
      end
    end
  end

  describe 'DELETE #destroy', :vcr do
    it 'sets the `deleted_at` column for the group assignment' do
      group_assignment

      expect do
        delete :destroy, params: { id: group_assignment.slug, organization_id: organization }
      end.to change { GroupAssignment.all.count }

      expect(GroupAssignment.unscoped.find(group_assignment.id).deleted_at).not_to be_nil
    end

    it 'calls the DestroyResource background job' do
      delete :destroy, params: { id: group_assignment.slug, organization_id: organization }

      assert_enqueued_jobs 1 do
        DestroyResourceJob.perform_later(group_assignment)
      end
    end

    it 'redirects back to the organization' do
      delete :destroy, params: { id: group_assignment.slug, organization_id: organization.slug }
      expect(response).to redirect_to(organization)
    end
  end
end
