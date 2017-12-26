#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
This test case validates style and function of Similarity Check Card, card settings page;
checks manually generation Similarity Check and checking results on iThenticate
with automation is Off;
checks triggering Report generetion with different card setting options.
Tests require 5 manuscript templates generated by test_a_2_add_stock_mmt.py.
"""
from datetime import datetime
import logging
import os
import random
import time

from Base.Decorators import MultiBrowserFixture
from Base.Resources import users, editorial_users, super_admin_login, handling_editor_login, \
    cover_editor_login, sim_check_full_submission_mmt, sim_check_major_revision_mmt, \
    sim_check_minor_revision_mmt, sim_check_first_revision_mmt
from frontend.common_test import CommonTest
from frontend.Cards.assign_team_card import AssignTeamCard
from frontend.Cards.register_decision_card import RegisterDecisionCard
from frontend.Cards.similarity_check_card import SimilarityCheckCard
from .Pages.admin_workflows import AdminWorkflowsPage
from frontend.Pages.manuscript_viewer import ManuscriptViewerPage
from frontend.Pages.workflow_page import WorkflowPage
from .Pages.sim_check_settings import SimCheckSettings

__author__ = 'gtimonina@plos.org'


@MultiBrowserFixture
class SimilarityCheckTest(CommonTest):
    """
    Validate the elements, styles, functions of the Similarity Check card

    """

    def rest_core_settings_validate_components_styles(self):
        """
        Validates elements and styles for the Similarity Check Settings page
        :return: void function
        """
        logging.info('Validating Similarity Check Settings: page components and styles')
        user_type = super_admin_login
        logging.info('Logging in as user: {0}'.format(user_type))
        dashboard_page = self.cas_login(email=user_type['email'])
        dashboard_page.page_ready()
        dashboard_page.click_admin_link()
        adm_wf_page = AdminWorkflowsPage(self.getDriver())
        adm_wf_page.page_ready()
        adm_wf_page.open_mmt('Similarity Check test')
        adm_wf_page.click_on_card_settings(adm_wf_page._similarity_check_card)

        card_settings = SimCheckSettings(self.getDriver())
        card_settings.overlay_ready()
        card_settings.validate_card_setting_style('Similarity Check: Settings')
        card_settings.validate_setting_style_and_components()

        card_settings.click_cancel()

    def rest_smoke_generate_manually_and_validate_access(self):
        """
        test_smoke_generate_manually_and_validate_access: two-in-one test
        Validates the similarity check card presence in a workflow view, generating report manually,
        validates access while the report is generating as it may take several minutes.
        Validates form elements and styles.
        Testing default settings, automation is Off.
        :return: void function
        """
        #
        # the card appears only in Workflow view
        current_path = os.getcwd()
        logging.info(current_path)

        logging.info('Test Similarity Check with Automation Off:: generate report '
                     'manually and validate access')

        # log as an author and create new submission
        creator_user = random.choice(users)
        doc_to_use = 'frontend/assets/docs/' \
                     'Cytoplasmic_Viruses_Rage_Against_the_Cellular_RNA_Decay_Machine.docx'
        # doc_to_use = 'frontend/assets/docs/' \
        #              'Preclinical_Applications_of_3-Deoxy-3-18F_Fluorothymidine_in_' \
        #              'Oncology-A_Systematic_.docx'
        title = 'Similarity Check test - manually generated report'
        short_doi, paper_url = self.create_new_submission(creator_user, title, doc_to_use,
                                                          mmt_name='Similarity Check test')

        # log as editorial user
        staff_user = random.choice(editorial_users)
        logging.info('Logging in as user: {0}'.format(staff_user['name']))
        dashboard_page = self.cas_login(email=staff_user['email'])
        dashboard_page.go_to_manuscript(short_doi)
        self._driver.navigated = True

        paper_viewer = ManuscriptViewerPage(self.getDriver())
        paper_viewer.page_ready()
        # AC#2 - check the card appears only in workflow view, not in manuscript view
        assert not paper_viewer.is_task_present("Similarity Check"), \
            "Similarity Check card should not be available in Manuscript view"
        # go to Workflow view
        paper_viewer._wait_for_element(paper_viewer._get(paper_viewer._tb_workflow_link))
        paper_viewer.click_workflow_link()
        workflow_page = WorkflowPage(self.getDriver())
        workflow_page.page_ready()

        workflow_page.click_card('similarity_check')
        sim_check = SimilarityCheckCard(self.getDriver())
        sim_check.card_ready()

        auto_setting_default = 'off'
        # get auto settings from db, it is expected to be off by default
        auto_settings_db = sim_check.get_sim_check_auto_settings(short_doi=short_doi)
        assert auto_settings_db == 'off', 'Automation setting in db: \'{0}\' is not ' \
                                          'the expected: \'{1}\''.format(auto_settings_db,
                                                                         auto_setting_default)

        sim_check.validate_card_header(short_doi)
        sim_check.validate_styles_and_components(auto_setting_default)

        task_url, start_time, pending_message, report_title = sim_check.generate_manual_report()
        assert "Pending" in pending_message, '\'Pending\' is expected in the message: {0}'\
            .format(pending_message)
        assert 'Similarity Check Report' in report_title, '\'Similarity Check Report\' is ' \
                                                          'expected in: '.format(report_title)
        sim_check.logout()

        # Similarity checks may take up to several minutes to complete,
        # so we'll use this time to run  access validation test
        logging.info("Switching to Access validation test at: {0}"
                     .format(start_time.strftime('%Y-%m-%dT%H:%M:%S.%fZ')))
        self.validate_access(staff_user)

        finish_time = datetime.now()
        diff_time = finish_time - start_time

        seconds_elapsed = diff_time.seconds
        logging.info("Access validation test finished at: {0}"
                     .format(finish_time.strftime('%Y-%m-%dT%H:%M:%S.%fZ')))

        logging.info('Elapsed time in seconds: {0}'.format(str(seconds_elapsed)))

        # log as staff_user
        logging.info('Logging in as user: {0} to validate similarity check report'
                     .format(staff_user['name']))
        dashboard_page = self.cas_login(email=staff_user['email'])
        dashboard_page.page_ready()
        self._driver.get(task_url)

        sim_check = SimilarityCheckCard(self.getDriver())
        sim_check.card_ready()
        seconds_to_wait = max(10, 600 - seconds_elapsed)
        logging.info('Starting report validation with maximum time to wait in seconds: '
                     '{0}'.format(str(seconds_to_wait)))
        self.validate_report_history(sim_check, version='0.0')

        report_validation_result, validation_seconds, paper_data, report_data = \
            sim_check.get_report_result(start_time)

        logging.info('Elapsed time for validation in seconds: '
                     '{0}'.format(str(validation_seconds)))

        # analyze the result
        if report_validation_result:
            # 10 min time out exception - error message is expected to be displaye
            assert 'Report not available:' in report_validation_result, report_validation_result
        else:
            # results assertion
            assert paper_data['title'] == report_data['title'], \
                'The title {0} is expected.'.format(paper_data['title'])
            assert paper_data['value'] in report_data['value'], 'Score {0} is expected in {1}' \
                .format(paper_data['value'], report_data['value'])
            assert paper_data['author'] in report_data['author'], \
                'Paper author {0} is expected in {1}'.format(paper_data['author'],
                                                             report_data['author'])

        sim_check.logout()

        # check that the Report generation is not triggered for the next revision:
        # log as editorial user
        staff_user = random.choice(editorial_users)
        workflow_page = self.go_to_ms_wokflow_as_editor(staff_user, paper_url)

        decision = random.choice(['Major Revision', 'Minor Revision'])
        # register decision
        self.make_register_decision(workflow_page, decision)
        workflow_page.logout()

        # Login as user and complete Revise Manuscript (Response to Reviewers)
        self.submit_new_version(short_doi, creator_user)

        # log as editorial user and open the manuscript in workflow view
        workflow_page = self.go_to_ms_wokflow_as_editor(staff_user, paper_url)
        workflow_page.click_card('similarity_check')
        # check AC#6: If the card is marked complete, it is not marked as incomplete
        # when a new version is submitted
        assert sim_check.completed_state()
        sim_check.validate_styles_and_components('off')
        # check Report History
        self.validate_report_history(sim_check, version='0.0')

    def validate_access(self, staff_user_to_skip):
        """
        Validates access of internal and external
        editorial users to the Similarity Check card
        :param staff_user_to_skip: staff user login to skip as it was checked in the previous test
        :return: void function
        """
        logging.info('Test Similarity Check::validate_access, default settings')

        # log as author and create new submission using 'Similarity Check test' mmt
        creator_user = random.choice(users)
        title = 'Similarity Check test with default settings - validate access'
        short_doi, paper_url = self.create_new_submission(creator_user, title, '',
                                                          'Similarity Check test')

        # set handler_and_cover_assigned to false to make sure handling and cover editors
        # assigned only ones
        handler_and_cover_assigned = False
        for staff_user in editorial_users:
            # skip staff user who was chosen and checked in the previous test
            if staff_user == staff_user_to_skip:
                continue
            logging.info('Logging in as user: {0}'.format(staff_user['name']))
            dashboard_page = self.cas_login(email=staff_user['email'])
            dashboard_page.page_ready()
            dashboard_page.go_to_manuscript(short_doi)
            self._driver.navigated = True
            paper_viewer = ManuscriptViewerPage(self.getDriver())
            # go to Workflow view
            paper_viewer._wait_for_element(paper_viewer._get(paper_viewer._tb_workflow_link))
            paper_viewer.click_workflow_link()
            workflow_page = WorkflowPage(self.getDriver())
            workflow_page.page_ready()

            workflow_page.click_card('similarity_check')
            sim_check = SimilarityCheckCard(self.getDriver())
            sim_check.card_ready()

            # sim_check.validate_card_header(short_doi)
            card_title = sim_check._get(sim_check._card_heading)
            assert card_title.text == 'Similarity Check'
            sim_check.validate_generate_report_button()

            # check the card is editable
            completed_section_button = sim_check._get(sim_check._btn_done)
            assert completed_section_button.text in ["MAKE CHANGES TO THIS TASK",
                                                     "I AM DONE WITH THIS TASK"], \
                completed_section_button.text

            # assign cover editor and handling editor to test their access to the card
            if not handler_and_cover_assigned:  # just to be sure we do it once
                sim_check.click_close_button_bottom()
                workflow_page._wait_on_lambda(lambda: workflow_page.get_current_url()
                                              .split('/')[-1] == 'workflow')
                workflow_page.click_card('assign_team')
                assign_team = AssignTeamCard(self.getDriver())
                assign_team.card_ready()
                assign_team.assign_role(cover_editor_login, 'Cover Editor')
                assign_team.assign_role(handling_editor_login, 'Handling Editor')
                handler_and_cover_assigned = True
            # logout
            sim_check.logout()

        # log as cover/handling editor
        # if manuscript is submitted, the card is read-only
        # so it should not be editable (confirmed by Shane)
        helping_editors = [cover_editor_login, handling_editor_login]
        for staff_user in helping_editors:
            logging.info('Logging in as user: {0}'.format(staff_user['name']))
            dashboard_page = self.cas_login(email=staff_user['email'])
            dashboard_page.page_ready()
            dashboard_page.go_to_manuscript(short_doi)
            self._driver.navigated = True
            paper_viewer = ManuscriptViewerPage(self.getDriver())
            # go to Workflow view
            paper_viewer._wait_for_element(paper_viewer._get(paper_viewer._tb_workflow_link))
            paper_viewer.click_workflow_link()
            workflow_page = WorkflowPage(self.getDriver())
            workflow_page.page_ready()
            workflow_page.click_card('similarity_check')
            sim_check = SimilarityCheckCard(self.getDriver())
            sim_check._wait_for_element(sim_check._get(sim_check._card_heading))
            card_title = sim_check._get(sim_check._card_heading)
            assert card_title.text == 'Similarity Check'
            assert sim_check._check_for_absence_of_element(sim_check._btn_done)

            # logout
            sim_check.logout()

    def rest_core_trigger_automated_report(self):
        """
        trigger_automated_report:
        Validates triggering the Report generation defined with card automation settings
        :return: void function
        """
        current_path = os.getcwd()
        logging.info(current_path)

        logging.info('Test Similarity Check with Automation ON:: generate report '
                     'manually and validate access')
        auto_options = (('at_first_full_submission', sim_check_full_submission_mmt['name']),
                        ('after_major_revise_decision', sim_check_major_revision_mmt['name']),
                        ('after_minor_revise_decision', sim_check_minor_revision_mmt['name']),
                        ('after_any_first_revise_decision', sim_check_first_revision_mmt['name']))

        auto_setting = random.choice(auto_options)
        # TODO: delete after debugging:
        auto_option = auto_setting[0]
        mmt_name = auto_setting[1]

        # log as an author and create new submission
        creator_user = random.choice(users)

        doc_to_use = 'frontend/assets/docs/' \
                     'Preclinical_Applications_of_3-Deoxy-3-18F_Fluorothymidine_in_' \
                     'Oncology-A_Systematic_.docx'  # error from ithenticate
        doc_to_use = 'frontend/assets/docs/Cytoplasmic_Viruses_Rage_Against_the_Cellular_' \
                     'RNA_Decay_Machine.docx'  # no error, index= 97
        title = 'Similarity Check test with auto trigger: ' + auto_option
        short_doi, paper_url = self.create_new_submission(creator_user, title, doc_to_use, mmt_name)

        # log as editorial user
        staff_user = random.choice(editorial_users)
        workflow_page = self.go_to_ms_wokflow_as_editor(staff_user, paper_url)

        workflow_page.click_card('similarity_check')
        sim_check = SimilarityCheckCard(self.getDriver())
        sim_check.card_ready()
        sim_check.validate_card_header(short_doi)
        if auto_option == 'at_first_full_submission':
            sim_check.validate_styles_and_components(auto_option, triggered=True)
            # check Report History
            self.validate_report_history(sim_check, version='0.0')

            sim_check.click_close_button_bottom()
            time.sleep(3)

            decision = random.choice(['Major Revision', 'Minor Revision'])
            # register decision
            self.make_register_decision(workflow_page, decision)
            workflow_page.logout()

            # Login as user and complete Revise Manuscript (Response to Reviewers)
            self.submit_new_version(short_doi, creator_user)

            # log as editorial user and open the manuscript in workflow view
            workflow_page = self.go_to_ms_wokflow_as_editor(staff_user, paper_url)
            workflow_page.click_card('similarity_check')
            sim_check.validate_styles_and_components(auto_option, triggered=False,
                                                     auto_report_done=True)
            # check Report History
            self.validate_report_history(sim_check, version='0.0')

        elif auto_option == 'after_any_first_revise_decision':
            sim_check.validate_styles_and_components(auto_option, triggered=False)

            sim_check.click_close_button_bottom()
            time.sleep(3)

            decision = random.choice(['Major Revision', 'Minor Revision'])
            # register decision
            self.make_register_decision(workflow_page, decision)
            workflow_page.logout()

            # Login as user and complete Revise Manuscript (Response to Reviewers)
            self.submit_new_version(short_doi, creator_user)
            # log as editorial user and open the manuscript in workflow view
            workflow_page = self.go_to_ms_wokflow_as_editor(staff_user, paper_url)
            workflow_page.click_card('similarity_check')
            sim_check.validate_styles_and_components(auto_option, triggered=True)
            self.validate_report_history(sim_check, version='1.0')

            sim_check.click_close_button_bottom()
            time.sleep(3)
            decision = random.choice(['Major Revision', 'Minor Revision'])
            # register decision
            self.make_register_decision(workflow_page, decision)
            workflow_page.logout()

            # Login as user and complete Revise Manuscript (Response to Reviewers)
            self.submit_new_version(short_doi, creator_user)
            # log as editorial user and open the manuscript in workflow view
            workflow_page = self.go_to_ms_wokflow_as_editor(staff_user, paper_url)
            workflow_page.click_card('similarity_check')
            sim_check.validate_styles_and_components(auto_option, triggered=False,
                                                     auto_report_done=True)
            # check Report History
            self.validate_report_history(sim_check, version='1.0')

        else:
            if auto_option == 'after_major_revise_decision':
                decision_steps = ['Major Revision', 'Minor Revision', 'Major Revision']
            else:
                decision_steps = ['Minor Revision', 'Major Revision', 'Minor Revision']
            sim_check.validate_styles_and_components(auto_option, triggered=False)

            sim_check.click_close_button_bottom()
            time.sleep(3)

            # register decision that should trigger automated report
            self.make_register_decision(workflow_page, decision=decision_steps[0])
            workflow_page.logout()

            # Login as user and complete Revise Manuscript (Response to Reviewers)
            self.submit_new_version(short_doi, creator_user)
            # log as editorial user and open the manuscript in workflow view
            workflow_page = self.go_to_ms_wokflow_as_editor(staff_user, paper_url)
            workflow_page.click_card('similarity_check')
            sim_check.validate_styles_and_components(auto_option, triggered=True)

            sim_check.click_close_button_bottom()
            time.sleep(3)
            # another register decision that should not trigger automated report
            self.make_register_decision(workflow_page, decision=decision_steps[1])
            workflow_page.logout()

            # Login as user and complete Revise Manuscript (Response to Reviewers)
            self.submit_new_version(short_doi, creator_user)
            # log as editorial user and open the manuscript in workflow view
            workflow_page = self.go_to_ms_wokflow_as_editor(staff_user, paper_url)
            workflow_page.click_card('similarity_check')
            sim_check.validate_styles_and_components(auto_option, triggered=False,
                                                     auto_report_done=True)
            self.validate_report_history(sim_check, version='1.0')

            sim_check.click_close_button_bottom()
            time.sleep(3)
            # same register decision as in step 1, should not trigger automated report
            # as only the first one must be a trigger
            self.make_register_decision(workflow_page, decision=decision_steps[2])
            workflow_page.logout()

            # Login as user and complete Revise Manuscript (Response to Reviewers)
            self.submit_new_version(short_doi, creator_user)
            # log as editorial user and open the manuscript in workflow view
            workflow_page = self.go_to_ms_wokflow_as_editor(staff_user, paper_url)
            workflow_page.click_card('similarity_check')
            sim_check.validate_styles_and_components(auto_option, triggered=False,
                                                     auto_report_done=True)
            # check Report History
            self.validate_report_history(sim_check, version='1.0')

    def test_core_disable_automation_by_manual_generation(self):
        """
        test_core_generate_manually_with_auto_settings:
        Validates APERTA-9958: Disable similarity check automation on manual report
        AC 1: User can disable report automation for an individual manuscript by running it manually
        AC 2: Once automation is disabled, it stays disabled for that manuscript

        Validates the similarity check card presence in a workflow view, generating report manually,
        validates access while the report is generating as it may take several minutes.
        Validates form elements and styles.
        Testing default settings, automation is Off.
        :return: void function
        """
        #
        # the card appears only in Workflow view
        current_path = os.getcwd()
        logging.info(current_path)

        logging.info('Test Similarity Check with Automation On:: disable automation by '
                     'sending report manually')

        auto_options = (('after_major_revise_decision', sim_check_major_revision_mmt['name']),
                        ('after_minor_revise_decision', sim_check_minor_revision_mmt['name']),
                        ('after_any_first_revise_decision', sim_check_first_revision_mmt['name']))

        auto_setting = random.choice(auto_options)
        # TODO: delete after debugging:
        auto_option = auto_setting[0]
        mmt_name = auto_setting[1]

        # log as an author and create new submission
        creator_user = random.choice(users)

        doc_to_use = 'frontend/assets/docs/' \
                     'Preclinical_Applications_of_3-Deoxy-3-18F_Fluorothymidine_in_' \
                     'Oncology-A_Systematic_.docx'  # error from ithenticate
        doc_to_use = 'frontend/assets/docs/Cytoplasmic_Viruses_Rage_Against_the_Cellular_' \
                     'RNA_Decay_Machine.docx'  # no error, index= 97
        title = 'Similarity Check test manual send report - disable auto trigger: ' \
                '{0}'.format(auto_option)
        short_doi, paper_url = self.create_new_submission(creator_user, title, doc_to_use, mmt_name)

        # log as editorial user
        staff_user = random.choice(editorial_users)
        logging.info('Logging in as user: {0}'.format(staff_user['name']))
        dashboard_page = self.cas_login(email=staff_user['email'])
        dashboard_page.go_to_manuscript(short_doi)
        self._driver.navigated = True

        paper_viewer = ManuscriptViewerPage(self.getDriver())
        paper_viewer.page_ready()
        # AC#2 - check the card appears only in workflow view, not in manuscript view
        assert not paper_viewer.is_task_present("Similarity Check"), \
            "Similarity Check card should not be available in Manuscript view"
        # go to Workflow view
        paper_viewer._wait_for_element(paper_viewer._get(paper_viewer._tb_workflow_link))
        paper_viewer.click_workflow_link()
        workflow_page = WorkflowPage(self.getDriver())
        workflow_page.page_ready()

        workflow_page.click_card('similarity_check')
        sim_check = SimilarityCheckCard(self.getDriver())
        sim_check.card_ready()

        auto_settings_db = sim_check.get_sim_check_auto_settings(short_doi=short_doi)
        assert auto_settings_db == auto_option, 'Automation setting in db: \'{0}\' is not ' \
                                          'the expected: \'{1}\''.format(auto_settings_db,
                                                                         auto_option)

        sim_check.validate_card_header(short_doi)
        sim_check.validate_styles_and_components(auto_option)

        task_url, start_time, pending_message, report_title = sim_check.generate_manual_report()
        assert "Pending" in pending_message, '\'Pending\' is expected in the message: {0}'\
            .format(pending_message)
        assert 'Similarity Check Report' in report_title, '\'Similarity Check Report\' is ' \
                                                          'expected in: '.format(report_title)

        sim_check.logout()

        # Similarity checks may take up to several minutes to complete,

        finish_time = datetime.now()
        diff_time = finish_time - start_time

        seconds_elapsed = diff_time.seconds
        logging.info("Access validation test finished at: {0}"
                     .format(finish_time.strftime('%Y-%m-%dT%H:%M:%S.%fZ')))

        logging.info('Elapsed time in seconds: {0}'.format(str(seconds_elapsed)))

        # log as staff_user
        logging.info('Logging in as user: {0} to validate similarity check report'
                     .format(staff_user['name']))
        dashboard_page = self.cas_login(email=staff_user['email'])
        dashboard_page.page_ready()
        self._driver.get(task_url)

        sim_check = SimilarityCheckCard(self.getDriver())
        sim_check.card_ready()
        seconds_to_wait = max(10, 600 - seconds_elapsed)
        logging.info('Starting report validation, expected maximum time to wait in seconds: '
                     '{0}'.format(str(seconds_to_wait)))
        self.validate_report_history(sim_check, version='0.0')

        # report_validation_result, validation_seconds, paper_data, report_data = \
        #     sim_check.get_report_result(start_time)
        #
        # logging.info('Elapsed time for validation in seconds: '
        #              '{0}'.format(str(validation_seconds)))
        #
        # # analyze the result
        # if report_validation_result:
        #     # 10 min time out exception - error message is expected to be displaye
        #     assert 'Report not available:' in report_validation_result, report_validation_result
        # else:
        #     # results assertion
        #     assert paper_data['title'] == report_data['title'], \
        #         'The title {0} is expected.'.format(paper_data['title'])
        #     assert paper_data['value'] in report_data['value'], 'Score {0} is expected in {1}' \
        #         .format(paper_data['value'], report_data['value'])
        #     assert paper_data['author'] in report_data['author'], \
        #         'Paper author {0} is expected in {1}'.format(paper_data['author'],
        #                                                      report_data['author'])

        sim_check.logout()

        # check that the Report generation is not triggered for the next revision:
        # log as editorial user
        staff_user = random.choice(editorial_users)
        workflow_page = self.go_to_ms_wokflow_as_editor(staff_user, paper_url)

        decision = random.choice(['Major Revision', 'Minor Revision'])
        # register decision
        self.make_register_decision(workflow_page, decision)
        workflow_page.logout()

        # Login as user and complete Revise Manuscript (Response to Reviewers)
        self.submit_new_version(short_doi, creator_user)

        # log as editorial user and open the manuscript in workflow view
        workflow_page = self.go_to_ms_wokflow_as_editor(staff_user, paper_url)
        workflow_page.click_card('similarity_check')
        # check AC#6: If the card is marked complete, it is not marked as incomplete
        # when a new version is submitted
        assert sim_check.completed_state()
        sim_check.validate_styles_and_components('off')
        # check Report History
        self.validate_report_history(sim_check, version='0.0')


    def validate_report_history(self, sim_check, version):
        """
        Validates Report History after Report generation
        :param sim_check: SimilarityCheckCard instance
        :param version: String, to validate version number in Report History
        :return: void function
        """
        # check Report History
        report_history_title, versions, last_version_report = sim_check.get_report_history()
        assert 'Report History' in report_history_title, '\'Report \' is expected in {0}'\
            .format(report_history_title)
        assert len(versions) == 1, '{0} versions in the Report History. Only one version ' \
                                   'of Report is expected.'.format(str(len(versions)))
        card_completed = sim_check.completed_state()
        if card_completed:
            assert 'Pending' not in last_version_report
        if version:
            assert version in versions[0]

    def make_register_decision(self, workflow_page, decision):
        """
        Method to create Register Decision by clicking and completion Register Decision Card
        using specified decision
        :param workflow_page: WorkflowPage instance
        :param decision: String, possible values: 'Major Revision', 'Minor Revision'
        :return: void function
        """
        workflow_page.click_card('register_decision')
        register_decision = RegisterDecisionCard(self.getDriver())
        register_decision.register_decision(decision)

    def submit_new_version(self, short_doi, creator_user):
        """
        Method to log in as an author and submit new version using the steps:
          complete 'Response to Reviewers', 'Title And Abstract', 'Upload Manuscript' cards
          submit new version and log out
        :param short_doi: string, used to go to the manuscript
        :param creator_user: author account
        :return: void function
        """
        # Login as user and complete Revise Manuscript (Response to Reviewers)
        logging.info('Logging in as user: {0}'.format(creator_user))
        dashboard_page = self.cas_login(email=creator_user['email'])
        dashboard_page.go_to_manuscript(short_doi)
        manuscript_page = ManuscriptViewerPage(self.getDriver())

        manuscript_page.page_ready()
        data = {'attach': 2}
        manuscript_page.complete_task('Response to Reviewers', data=data)
        # This needs to be completed after any decision
        manuscript_page.complete_task('Title And Abstract')
        manuscript_page.complete_task('Upload Manuscript')
        # submit and logout
        time.sleep(1)
        manuscript_page.click_submit_btn()
        manuscript_page.confirm_submit_btn()
        manuscript_page.close_submit_overlay()
        manuscript_page.logout()

    def go_to_ms_wokflow_as_editor(self, staff_user, paper_url):
        """
        Method to log in as an staff user and navigate  directly to manuscript workflow view
        :param staff_user: staff user account
        :param paper_url: string, used to navigate  directly to manuscript workflow view
        :return: workflow_page: WorkflowPage instance
        """
        # log as editorial user
        # staff_user = random.choice(editorial_users)
        logging.info('Logging in as user: {0}'.format(staff_user['name']))
        dashboard_page = self.cas_login(email=staff_user['email'])
        dashboard_page._wait_on_lambda(
                lambda: paper_url.split('/')[2] in dashboard_page.get_current_url())
        # dashboard_page.page_ready()
        # navigate directly to manuscript workflow view
        paper_workflow_url = '{0}/workflow'.format(paper_url)
        self._driver.get(paper_workflow_url)
        workflow_page = WorkflowPage(self.getDriver())
        workflow_page.page_ready()
        return workflow_page

    def create_new_submission(self, creator_user, title, document, mmt_name):
        """
        Method to log in as a creator user and create new submission
        :param creator_user: specific creator user account
        :param title: string, title of created manuscript
        :param document: Name of the document to upload. If blank will default to 'random',
        this will choose one of available papers
        :param mmt_name: type of the manuscript
        :return: short_doi, paper_url
        """
        dashboard_page = self.cas_login(email=creator_user['email'])
        dashboard_page.click_create_new_submission_button()

        # TODO: use any file, not only word
        self.create_article(title=title, journal='PLOS Wombat', type_=mmt_name,
                            document=document,
                            random_bit=True, format_='word')
        #
        manuscript_page = ManuscriptViewerPage(self.getDriver())
        manuscript_page.page_ready()
        short_doi = manuscript_page.get_paper_short_doi_from_url()
        paper_url = manuscript_page.get_current_url_without_args()
        logging.info("Assigned paper short doi: {0}".format(short_doi))
        # Complete cards
        manuscript_page.complete_task('Upload Manuscript')
        manuscript_page.complete_task('Title And Abstract')
        manuscript_page.click_submit_btn()
        manuscript_page.confirm_submit_btn()
        manuscript_page.close_submit_overlay()
        # logout
        manuscript_page.logout()
        return short_doi, paper_url


if __name__ == '__main__':
    CommonTest.run_tests_randomly()
