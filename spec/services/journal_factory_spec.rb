require 'rails_helper'

describe JournalFactory do
  describe '.create' do
    include AuthorizationSpecHelper

    it 'creates a new journal' do
      expect do
        JournalFactory.create(name: 'Journal of the Stars')
      end.to change(Journal, :count).by(1)
    end

    it 'uses the given params to create the new journal' do
      journal = JournalFactory.create(name: 'Journal of the Stars')
      expect(journal.name).to eq('Journal of the Stars')
    end

    context 'creating the default roles and permission for the journal' do
      before(:all) do
        clear_roles_and_permissions
        JournalFactory.create(name: 'Genetics Journal')
      end

      after(:all) do
        clear_roles_and_permissions
      end

      let!(:journal) { Journal.first! }
      let(:view_paper_permission) do
        Permission.where(action: 'view', applies_to: 'Paper').first
      end

      it 'gives the journal its own Creator role' do
        expect(journal.creator_role).to be
      end

      context 'Creator role' do
        it 'gets the :view Paper permission with no state requirements' do
          expect(journal.creator_role.permissions).to include(
            view_paper_permission
          )
          expect(view_paper_permission.states).to contain_exactly(
            PermissionState.wildcard
          )
        end

        describe 'permissions on tasks' do
          let(:accessible_task_klasses) do
            ::Task.submission_task_types + [PlosBioTechCheck::ChangesForAuthorTask]
          end
          let(:all_inaccessible_task_klasses) do
            ::Task.descendants - accessible_task_klasses
          end

          it 'can :view and :edit all Tasks except ProductionMetadataTask' do
            accessible_task_klasses.each do |klass|
              expect(journal.creator_role.permissions).to include(
                Permission.find_by(action: :view, applies_to: klass.name),
                Permission.find_by(action: :edit, applies_to: klass.name)
              )
            end

            all_inaccessible_task_klasses.each do |klass|
              expect(journal.creator_role.permissions).to_not include(
                Permission.find_by(action: :view, applies_to: klass.name),
                Permission.find_by(action: :edit, applies_to: klass.name)
              )
            end
          end

          it 'can view/add/remove participants on all Tasks except ProductionMetadataTask' do
            accessible_task_klasses.each do |klass|
              expect(journal.creator_role.permissions).to include(
                Permission.find_by(action: :view_participants, applies_to: klass.name),
                Permission.find_by(action: :manage_participant, applies_to: klass.name)
              )
            end

            all_inaccessible_task_klasses.each do |klass|
              expect(journal.creator_role.permissions).to_not include(
                Permission.find_by(action: :view_participants, applies_to: klass.name),
                Permission.find_by(action: :manage_participant, applies_to: klass.name)
              )
            end
          end
        end
      end

      it 'gives the journal its own Collaborator role' do
        expect(journal.collaborator_role).to be
      end

      context 'Collaborator role' do
        it 'gets the :view Paper permission with no state requirements' do
          expect(journal.collaborator_role.permissions).to include(
            Permission.where(action: 'view', applies_to: 'Paper').first
          )
          expect(view_paper_permission.states).to contain_exactly(
            PermissionState.wildcard
          )
        end

        describe 'permissions on tasks' do
          let(:accessible_task_klasses) do
            accessible_for_role = ::Task.descendants.select do |klass|
              klass <=> SubmissionTask
            end
            accessible_for_role - inaccessible_task_klasses
          end
          let(:inaccessible_task_klasses) do
            [PlosBilling::BillingTask]
          end
          let(:all_inaccessible_task_klasses) do
            ::Task.descendants - accessible_task_klasses
          end

          it 'can :view and :edit all accessible_task_klasses' do
            accessible_task_klasses.each do |klass|
              expect(journal.collaborator_role.permissions).to include(
                Permission.find_by(action: :view, applies_to: klass.name),
                Permission.find_by(action: :edit, applies_to: klass.name)
              )
            end

            all_inaccessible_task_klasses.each do |klass|
              expect(journal.collaborator_role.permissions).to_not include(
                Permission.find_by(action: :view, applies_to: klass.name),
                Permission.find_by(action: :edit, applies_to: klass.name)
              )
            end
          end

          it 'can view/manage participants on all accessible_task_klasses' do
            accessible_task_klasses.each do |klass|
              expect(journal.collaborator_role.permissions).to include(
                Permission.find_by(action: :view_participants, applies_to: klass.name),
                Permission.find_by(action: :manage_participant, applies_to: klass.name),
              )
            end

            all_inaccessible_task_klasses.each do |klass|
              expect(journal.collaborator_role.permissions).to_not include(
                Permission.find_by(action: :view_participants, applies_to: klass.name),
                Permission.find_by(action: :manage_participant, applies_to: klass.name)
              )
            end
          end
        end
      end

      context 'Cover Editor role' do
        context 'has Paper permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'Paper', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_workflow' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_workflow')
            )
          end

          it ':manage_collaborators' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_collaborators')
            )
          end

          it ':start_discussion' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'start_discussion')
            )
          end

          it ':view_user_role_eligibility_on_paper' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'view_user_role_eligibility_on_paper')
            )
          end

          it ':assign_roles' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'assign_roles')
            )
          end
        end

        context 'has Task permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'Task', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_participant' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end

          it ':manage_invitations' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end
        end

        context 'has DiscussionTopic permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'DiscussionTopic', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_participant' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end

          it ':reply' do
            expect(journal.cover_editor_role.permissions).to include(
              permissions.find_by(action: 'reply')
            )
          end
        end

        describe 'permission to PlosBilling::BillingTask' do
          it 'cannot :view or :edit' do
            expect(journal.cover_editor_role.permissions).not_to include(
              Permission.find_by(action: 'view', applies_to: 'PlosBilling::BillingTask'),
              Permission.find_by(action: 'edit', applies_to: 'PlosBilling::BillingTask')
            )
          end
        end
      end

      context 'Academic Editor' do
        describe 'permissions on tasks' do
          let(:accessible_task_klasses) do
            accessible_for_role = ::Task.submission_task_types + [TahiStandardTasks::ReviewerReportTask]
            accessible_for_role - inaccessible_task_klasses
          end
          let(:inaccessible_task_klasses) do
            [PlosBilling::BillingTask, TahiStandardTasks::RegisterDecisionTask]
          end
          let(:all_inaccessible_task_klasses) do
            ::Task.descendants - accessible_task_klasses
          end

          it 'can :view all accessible_task_klasses' do
            accessible_task_klasses.each do |klass|
              expect(journal.academic_editor_role.permissions).to include(
                Permission.find_by(action: :view, applies_to: klass.name)
              )
            end

            all_inaccessible_task_klasses.each do |klass|
              expect(journal.academic_editor_role.permissions).to_not include(
                Permission.find_by(action: :view, applies_to: klass.name)
              )
            end
          end

          it 'is able to view and edit the ReviewerRecommendationsTask' do
            expect(journal.academic_editor_role.permissions).to include(
              Permission.where(action: 'view', applies_to: 'TahiStandardTasks::ReviewerRecommendationsTask').first
            )
            expect(journal.academic_editor_role.permissions).to include(
              Permission.where(action: 'edit', applies_to: 'TahiStandardTasks::ReviewerRecommendationsTask').first
            )
          end
        end
      end

      context 'Handling Editor' do
        context 'has Paper permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'Paper', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_workflow' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_workflow')
            )
          end

          it ':manage_collaborators' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_collaborators')
            )
          end

          it ':start_discussion' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'start_discussion')
            )
          end

          it ':view_user_role_eligibility_on_paper' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'view_user_role_eligibility_on_paper')
            )
          end

          it ':assign_roles' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'assign_roles')
            )
          end
        end

        context 'has Task permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'Task', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_participant' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end

          it ':manage_invitations' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end
        end

        context 'has DiscussionTopic permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'DiscussionTopic', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_participant' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end

          it ':reply' do
            expect(journal.handling_editor_role.permissions).to include(
              permissions.find_by(action: 'reply')
            )
          end
        end

        describe 'permission to PlosBilling::BillingTask' do
          it 'cannot :view or :edit' do
            expect(journal.handling_editor_role.permissions).not_to include(
              Permission.find_by(action: 'view', applies_to: 'PlosBilling::BillingTask'),
              Permission.find_by(action: 'edit', applies_to: 'PlosBilling::BillingTask')
            )
          end
        end
      end

      context 'Internal Editor' do
        context 'has Paper permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'Paper', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_workflow' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_workflow')
            )
          end

          it ':manage_collaborators' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_collaborators')
            )
          end

          it ':start_discussion' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'start_discussion')
            )
          end

          it ':view_user_role_eligibility_on_paper' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'view_user_role_eligibility_on_paper')
            )
          end

          it ':assign_roles' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'assign_roles')
            )
          end
        end

        context 'has Task permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'Task', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_participant' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end

          it ':manage_invitations' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end
        end

        context 'has DiscussionTopic permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'DiscussionTopic', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_participant' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end

          it ':reply' do
            expect(journal.internal_editor_role.permissions).to include(
              permissions.find_by(action: 'reply')
            )
          end
        end

        describe 'permission to PlosBilling::BillingTask' do
          it 'cannot :view or :edit' do
            expect(journal.internal_editor_role.permissions).not_to include(
              Permission.find_by(action: 'view', applies_to: 'PlosBilling::BillingTask'),
              Permission.find_by(action: 'edit', applies_to: 'PlosBilling::BillingTask')
            )
          end
        end
      end

      context 'Production Staff' do
        context 'has Paper permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'Paper', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_workflow' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'manage_workflow')
            )
          end

          it ':manage_collaborators' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'manage_collaborators')
            )
          end

          it ':start_discussion' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'start_discussion')
            )
          end

          it ':view_user_role_eligibility_on_paper' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'view_user_role_eligibility_on_paper')
            )
          end

          it ':assign_roles' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'assign_roles')
            )
          end
        end

        context 'has Task permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'Task', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_participant' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end

          it ':manage_invitations' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end
        end

        context 'has DiscussionTopic permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'DiscussionTopic', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_participant' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end

          it ':reply' do
            expect(journal.production_staff_role.permissions).to include(
              permissions.find_by(action: 'reply')
            )
          end
        end

        describe 'permission to PlosBilling::BillingTask' do
          it ':view and :edit' do
            expect(journal.production_staff_role.permissions).to include(
              Permission.find_by(action: 'view', applies_to: 'PlosBilling::BillingTask'),
              Permission.find_by(action: 'edit', applies_to: 'PlosBilling::BillingTask')
            )
          end
        end
      end

      context 'Publishing Services' do
        context 'has Paper permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'Paper', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_workflow' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'manage_workflow')
            )
          end

          it ':manage_collaborators' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'manage_collaborators')
            )
          end

          it ':start_discussion' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'start_discussion')
            )
          end

          it ':view_user_role_eligibility_on_paper' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'view_user_role_eligibility_on_paper')
            )
          end

          it ':assign_roles' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'assign_roles')
            )
          end
        end

        context 'has Task permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'Task', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_participant' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end

          it ':manage_invitations' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end
        end

        context 'has DiscussionTopic permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'DiscussionTopic', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_participant' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end

          it ':reply' do
            expect(journal.publishing_services_role.permissions).to include(
              permissions.find_by(action: 'reply')
            )
          end
        end

        describe 'permission to PlosBilling::BillingTask' do
          it ':view and :edit' do
            expect(journal.publishing_services_role.permissions).to include(
              Permission.find_by(action: 'view', applies_to: 'PlosBilling::BillingTask'),
              Permission.find_by(action: 'edit', applies_to: 'PlosBilling::BillingTask')
            )
          end
        end
      end

      context 'Discussion Participant' do
        context 'has DiscussionTopic permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'DiscussionTopic', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.discussion_participant_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':reply' do
            expect(journal.discussion_participant_role.permissions).to include(
              permissions.find_by(action: 'reply')
            )
          end
        end
      end

      context 'Reviewer' do
        describe 'permissions on tasks' do
          let(:permissions) do
            Permission.joins(:states).where(
              permission_states: { id: PermissionState.wildcard }
            )
          end

          let(:accessible_task_klasses) do
            Task.submission_task_types - inaccessible_task_klasses
          end
          let(:inaccessible_task_klasses) do
            [
              PlosBilling::BillingTask,
              TahiStandardTasks::CoverLetterTask,
              TahiStandardTasks::ReviewerRecommendationsTask
            ]
          end
          let(:all_inaccessible_task_klasses) do
            ::Task.descendants - accessible_task_klasses
          end

          it 'can :view associated Paper' do
            expect(journal.reviewer_role.permissions).to include(
              permissions.find_by(action: :view, applies_to: 'Paper')
            )
          end

          it 'can :view and :view_participants accessible task klasses' do
            accessible_task_klasses.each do |klass|
              expect(journal.reviewer_role.permissions).to include(
                permissions.find_by(action: :view, applies_to: klass.name),
                permissions.find_by(action: :view_participants, applies_to: klass.name)
              )
            end
          end

          it 'cannot :view or :view_participants on inaccessible task klasses' do
            all_inaccessible_task_klasses.each do |klass|
              expect(journal.reviewer_role.permissions).to_not include(
                permissions.find_by(action: :view, applies_to: klass.name),
                permissions.find_by(action: :view_participants, applies_to: klass.name)
              )
            end
          end
        end
      end

      context 'Staff Admin' do
        context 'has Paper permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'Paper', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_workflow' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'manage_workflow')
            )
          end

          it ':manage_collaborators' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'manage_collaborators')
            )
          end

          it ':start_discussion' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'start_discussion')
            )
          end

          it ':view_user_role_eligibility_on_paper' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'view_user_role_eligibility_on_paper')
            )
          end

          it ':assign_roles' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'assign_roles')
            )
          end
        end

        context 'has Task permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'Task', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_participant' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end

          it ':manage_invitations' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end
        end

        context 'has DiscussionTopic permission to' do
          let(:permissions) { Permission.joins(:states).where(applies_to: 'DiscussionTopic', permission_states: { id: PermissionState.wildcard }) }

          it ':view' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'view')
            )
          end

          it ':edit' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'edit')
            )
          end

          it ':manage_participant' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'manage_participant')
            )
          end

          it ':reply' do
            expect(journal.staff_admin_role.permissions).to include(
              permissions.find_by(action: 'reply')
            )
          end
        end

        describe 'permission to PlosBilling::BillingTask' do
          it ':view and :edit' do
            expect(journal.staff_admin_role.permissions).to include(
              Permission.find_by(action: 'view', applies_to: 'PlosBilling::BillingTask'),
              Permission.find_by(action: 'edit', applies_to: 'PlosBilling::BillingTask')
            )
          end
        end
      end
    end
  end
end
