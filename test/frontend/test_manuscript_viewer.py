# -*- coding: utf-8 -*-
"""
This test case validates the article editor page and its associated overlays.
"""

import logging
import os
import random

import pytest

from Base.Decorators import MultiBrowserFixture
from Base.CustomException import ElementDoesNotExistAssertionError
from Base.Resources import users, editorial_users, admin_users, super_admin_login, \
    handling_editor_login, academic_editor_login, internal_editor_login
from Base.PostgreSQL import PgSQL
from .Pages.manuscript_viewer import ManuscriptViewerPage
from .Pages.workflow_page import WorkflowPage
from .Cards.initial_decision_card import InitialDecisionCard
from .Tasks.figures_task import FiguresTask
from .Tasks.upload_manuscript_task import UploadManuscriptTask
from frontend.common_test import CommonTest

__author__ = 'sbassi@plos.org'

# Note temporary redefining external editorial without cover_editor_login from the pool
# of external users due to APERTA-9007
external_editorial_users = [handling_editor_login, academic_editor_login]


@MultiBrowserFixture
class ManuscriptViewerTest(CommonTest):
    """
    This class implements:
      APERTA-5515
      APERTA-3
    """

    def test_validate_components_styles(self):
        """
        test_manuscript_viewer: Validate elements and styles for the manuscript viewer page
        APERTA-3: validate page elements and styles
        Validates the presence of the following elements:
          - icons in text area (editor menu)
          - button for comparing versions
          - button for adding collaborators
          - button for paper download
          - button for recent activity
          - button for discussions
          - button for workflow
          - button for more options
        """
        logging.info('Test Manuscript Viewer::components_styles')
        current_path = os.getcwd()
        logging.info(current_path)
        all_users = users + editorial_users + external_editorial_users + admin_users
        user = random.choice(all_users)
        logging.info('Running test_validate_components_styles')
        logging.info('Logging in as {0}'.format(user))
        dashboard_page = self.cas_login(email=user['email'])
        dashboard_page.page_ready()
        # create a new manuscript
        dashboard_page.click_create_new_submission_button()
        self.create_article(title='Test Manuscript Viewer - components_styles',
                            journal='PLOS Wombat', type_='Images+InitialDecision', random_bit=True)
        manuscript_page = ManuscriptViewerPage(self.getDriver())
        manuscript_page.page_ready()
        manuscript_page.close_infobox()
        manuscript_page.validate_independent_scrolling()
        manuscript_page.validate_nav_toolbar_elements(user)
        if user in admin_users:
            manuscript_page.validate_page_elements_styles_functions(user=user['email'], admin=True)
        else:
            manuscript_page.validate_page_elements_styles_functions(user=user['email'], admin=False)
        return self

    def test_role_aware_menus(self):
        """
        APERTA-3: Validates role aware menus
        """
        logging.info('Test Manuscript Viewer::Role Aware Menus')
        current_path = os.getcwd()
        logging.info(current_path)
        roles = {'Creator': 6, 'Freelance Editor': 6, 'Staff Admin': 7, 'Publishing Services': 7,
                 'Production Staff': 7, 'Site Admin': 7, 'Internal Editor': 7, 'Billing Staff': 7,
                 'Participant': 6, 'Discussion Participant': 6, 'Collaborator': 6,
                 'Academic Editor': 6,
                 'Handling Editor': 6, 'Cover Editor': 6, 'Reviewer': 7, 'Journal Setup Admin': 7}
        random_users = [random.choice(users), random.choice(editorial_users),
                        random.choice(external_editorial_users), random.choice(admin_users)]
        for user in random_users:
            logging.info('Logging in as user: {0}'.format(user))
            dashboard_page = self.cas_login(user['email'])
            dashboard_page.page_ready()
            if dashboard_page.get_dashboard_ms(user):
                try:  # Logged in user may not have any manuscripts
                    self.select_preexisting_article(first=True)
                except ElementDoesNotExistAssertionError:
                    dashboard_page.click_create_new_submission_button()
                    self.create_article(title='manuscript_viewer::test_role_aware_menus',
                                        journal='PLOS Wombat', type_='NoCards')
                    manuscript_page = ManuscriptViewerPage(self.getDriver())
                    manuscript_page.page_ready_post_create()

                manuscript_page = ManuscriptViewerPage(self.getDriver())
                manuscript_page.page_ready()
                journal_id = manuscript_page.get_journal_id()
                uid = PgSQL().query(
                        'SELECT id FROM users WHERE username = %s;', (user['user'],))[0][0]
                short_doi = manuscript_page.get_paper_short_doi_from_url()
                paper_id = manuscript_page.get_paper_id_from_short_doi(short_doi)
                journal_permissions = PgSQL().query(
                    'SELECT name FROM roles WHERE id IN (SELECT role_id'
                    ' FROM assignments WHERE ((assigned_to_id = %s AND '
                    'assigned_to_type = \'Journal\' AND user_id = %s)));',
                    (journal_id, uid))
                paper_permissions = PgSQL().query(
                    'SELECT name FROM roles WHERE id IN (SELECT role_id '
                    'FROM assignments WHERE ((assigned_to_id = %s AND '
                    'assigned_to_type = \'Paper\' AND user_id = %s)));',
                    (paper_id, uid))
                system_permissions = PgSQL().query(
                    'SELECT name FROM roles WHERE id IN (SELECT role_id '
                    'FROM assignments WHERE ((assigned_to_type = '
                    '\'System\' AND user_id = %s)));', (uid,))
                permissions = journal_permissions + paper_permissions + system_permissions
                logging.info('DB Permissions: {0}'.format(permissions))
                max_elements = max([roles[item] for sublist in permissions for item in sublist])
                logging.info(
                    u'Validate user {0} in paper {1} with permissions {2} and max_elements {3}'
                    .format(user['user'], short_doi, permissions, max_elements))
                # NOTE: When covereditor is selected, the assert fails.
                manuscript_page.validate_roles(max_elements, user['user'])
            else:
                logging.info(u'No manuscripts present for user: {0}'.format(user['user']))
            dashboard_page.logout()
        return self

    @pytest.mark.single
    def test_initial_submission_infobox(self):
        """
        test_manuscript_viewer: Validate elements and styles of the initial submission infobox
        Aperta-5515

        AC from Aperta-5515:
          1. When the page is opened for first time, check for info box.
          2. Test closing the info box
          3. Info box appears for initial manuscript view only, whether the user closes or leaves it
              open
          4. Info box does not appear for Collaborators
          5. Message for initial submission when there are still cards to fill
          6. Message for initial submission when is ready for submission
          7. Message for full submission when there are still cards to fill
          8. Message for full submission when is ready for submission
          9. Show "[Journal Name] submission process (?)" on top of the card stack at all times.
          10. Clicking the question mark opens the "[Journal Name] submission process" info box

        Notes:
          AC#4 disabled until APERTA-5987 is fixed
          AC#7 on hold until APERTA-5718 is fixed.
          AC#10 on hold until APERTA-5725 is fixed
        """
        logging.info('Test Manuscript Viewer::initial submission infobox')
        user = random.choice(users)
        logging.info('Logging in as user: {0}'.format(user))
        dashboard_page = self.cas_login(email=user['email'])
        dashboard_page.page_ready()
        dashboard_page.click_create_new_submission_button()
        # due to APERTA-11669 we need to know document format to check AC2
        format = random.choice(['pdf', 'word'])
        self.create_article(title='Test Manuscript Viewer - initial submission infobox',
                            journal='PLOS Wombat', type_='Images+InitialDecision', random_bit=True,
                            format_=format)
        manuscript_page = ManuscriptViewerPage(self.getDriver())
        # Note that the following method closes the infobox as well as the success/failure
        # flash alert
        manuscript_page.page_ready_post_create()
        paper_url = manuscript_page.get_current_url()
        logging.info('The paper ID of this newly created paper is: {0}'.format(paper_url))
        # AC5 Test for Message for initial submission
        assert 'Please provide the following information to submit your manuscript for Initial ' \
               'Submission.' in manuscript_page.get_submission_status_initial_submission_todo(), \
            manuscript_page.get_submission_status_initial_submission_todo()
        manuscript_page.set_timeout(1)

        # AC2: Test closing the info box
        # APERTA-11669: No flash messages on creation of manuscript via pdf
        # closing flash message for word files closes also infobox, we have to close infobox for pdf
        # TODO: remove next 2 lines once APERTA-11669 gets resolved
        if format == 'pdf':
            manuscript_page.close_infobox()
        try:
            manuscript_page.get_infobox()
        except ElementDoesNotExistAssertionError:
            assert True
        else:
            assert False, "Infobox still open. AC2 fails"
        manuscript_page.restore_timeout()
        # AC3 Green info box appears for initial manuscript view only - whether the user closes or
        #   leaves it open
        manuscript_page.click_aperta_dashboard_link()
        self._driver.get(paper_url)
        manuscript_page = ManuscriptViewerPage(self.getDriver())
        manuscript_page.page_ready()
        manuscript_page.set_timeout(.5)
        try:
            manuscript_page.get_infobox()
        except ElementDoesNotExistAssertionError:
            assert True
        else:
            assert False, "Infobox still open. AC3 fails"
        manuscript_page.restore_timeout()
        # Open infobox with question mark icon. AC#10
        manuscript_page.click_question_mark()
        manuscript_page.get_infobox()

        manuscript_page = ManuscriptViewerPage(self.getDriver())
        # Add a collaborator (for AC4)
        # APERTA-6840 - we disabled add collaborators temporarily
        # manuscript_page.add_collaborators(creator_login4)
        paper_id = manuscript_page.get_current_url().split('/')[-1]
        # Complete IMG card to force display of submission status
        logging.debug('Opening the Figures task')
        manuscript_page.click_task('Figures')
        figures_task = FiguresTask(self.getDriver())
        figures_task.task_ready()
        manuscript_page.complete_task('Figures')
        manuscript_page.complete_task('Upload Manuscript')
        manuscript_page.complete_task('Title And Abstract')
        # NOTE: At this point browser renders the page with errors only on automation runs
        # AC 6
        assert "Your manuscript is ready for Initial Submission." in \
               manuscript_page.get_submission_status_ready2submit_text(), \
            manuscript_page.get_submission_status_ready2submit_text()
        # APERTA-6840 - we disabled add collaborators temporarily
        # manuscript_page.logout()
        # dashboard_page = self.cas_login(email=creator_login4['email'], password=login_valid_pw)
        # dashboard_page.page_ready()
        # dashboard_page.go_to_manuscript(paper_id)
        # manuscript_page = ManuscriptViewerPage(self.getDriver())
        # manuscript_page.page_ready()
        # manuscript_page.set_timeout(.5)
        # # AC4 Green info box does not appear for collaborators
        # try:
        #   manuscript_page.get_infobox()
        # except ElementDoesNotExistAssertionError:
        #   assert True
        # else:
        #   assert False, "Infobox still open. AC4 fails"
        # manuscript_page.restore_timeout()
        # Submit
        manuscript_page.click_submit_btn()
        manuscript_page.confirm_submit_btn()
        manuscript_page.close_modal()
        manuscript_page.logout()

        # Approve initial Decision
        logging.info('Logging in as user: {0}'.format(super_admin_login['user']))
        dashboard_page = self.cas_login(email=super_admin_login['email'])
        dashboard_page.page_ready()
        dashboard_page.go_to_manuscript(paper_id)
        manuscript_page = ManuscriptViewerPage(self.getDriver())
        manuscript_page.page_ready()
        manuscript_page.click_workflow_link()
        workflow_page = WorkflowPage(self.getDriver())
        workflow_page.click_card('initial_decision')
        initial_decision_card = InitialDecisionCard(self.getDriver())
        initial_decision_card.card_ready()
        initial_decision_card.execute_decision('invite')
        workflow_page.logout()

        # Test for AC8
        logging.info('Logging in as user: {0}'.format(user))
        dashboard_page = self.cas_login(email=user['email'])
        dashboard_page.page_ready()
        dashboard_page.go_to_manuscript(paper_id)
        manuscript_page = ManuscriptViewerPage(self.getDriver())
        manuscript_page.page_ready()
        # AC8: Message for full submission when is ready for submission
        manuscript_page._get(manuscript_page._nav_aperta_dashboard_link)
        assert 'Your manuscript is ready for Full Submission.' in \
               manuscript_page.get_submission_status_ready2submit_text(), \
            manuscript_page.get_submission_status_ready2submit_text()
        return self

    def test_paper_download(self):
        """
        test_manuscript_viewer: Validates the download functions for different
        versions, formats, UI elements and styles
        :return: void function
        """
        logging.info('Test Manuscript Viewer::paper_download')
        current_path = os.getcwd()
        logging.info(current_path)
        user = random.choice(users)
        dashboard_page = self.cas_login(email=user['email'])
        dashboard_page.page_ready()
        # create a new manuscript
        dashboard_page.click_create_new_submission_button()
        dashboard_page._wait_for_element(
            dashboard_page._get(dashboard_page._cns_paper_type_chooser))
        self.create_article(title='Test Manuscript Viewer - paper_download', journal='PLOS Wombat',
                            type_='NoCards', random_bit=True, format_='pdf')
        manuscript_page = ManuscriptViewerPage(self.getDriver())
        manuscript_page.page_ready_post_create()
        short_doi = manuscript_page.get_paper_short_doi_from_url()
        manuscript_page.complete_task('Upload Manuscript')
        manuscript_page.complete_task('Title And Abstract')
        # Make submission
        manuscript_page.click_submit_btn()
        manuscript_page.confirm_submit_btn()
        manuscript_page.close_submit_overlay()
        # Logout
        manuscript_page.logout()

        logging.info('Logging in as the Internal Editor to Register a Decision')
        # Log as editor to approve the manuscript with modifications
        dashboard_page = self.cas_login(email=internal_editor_login['email'])
        # Go to article
        dashboard_page.go_to_manuscript(short_doi)
        manuscript_page = ManuscriptViewerPage(self.getDriver())
        manuscript_page.click_workflow_link()
        workflow_page = WorkflowPage(self.getDriver())
        workflow_page.click_register_decision_card()
        workflow_page.complete_card('Register Decision')
        manuscript_page.logout()

        # Log in as a author to upload the word version
        logging.info('Logging in as creator to upload a word version')
        dashboard_page = self.cas_login(email=user['email'])
        dashboard_page.page_ready()
        dashboard_page.go_to_manuscript(short_doi)
        manuscript_page = ManuscriptViewerPage(self.getDriver())
        manuscript_page.page_ready()
        manuscript_page.click_task('Upload Manuscript')
        upms = UploadManuscriptTask(self.getDriver())
        upms._wait_for_element(upms._get(upms._upload_source_file_button))
        upms.replace_manuscript()
        upms.validate_ihat_conversions_success(timeout=45)
        data = {'attach': 2}
        manuscript_page.click_task('Upload Manuscript')
        manuscript_page.complete_task('Upload Manuscript')
        manuscript_page.complete_task('Title And Abstract')
        manuscript_page.complete_task('Response to Reviewers', data=data)
        # Make new submission
        manuscript_page.click_submit_btn()
        manuscript_page.confirm_submit_btn()
        manuscript_page.close_submit_overlay()
        # Logout
        manuscript_page.logout()

        logging.info('Logging in as the Internal Editor to Register a Decision')
        # Log as editor to approve the manuscript with modifications
        dashboard_page = self.cas_login(email=internal_editor_login['email'])
        # Go to article
        dashboard_page.go_to_manuscript(short_doi)
        manuscript_page = ManuscriptViewerPage(self.getDriver())
        manuscript_page.click_workflow_link()
        workflow_page = WorkflowPage(self.getDriver())
        workflow_page.click_register_decision_card()
        workflow_page.complete_card('Register Decision')
        manuscript_page.logout()

        # Log in as a author to validate the download drawer
        logging.info('Logging in as author to validate the download drawer')
        dashboard_page = self.cas_login(email=user['email'])
        dashboard_page.page_ready()
        dashboard_page.go_to_manuscript(short_doi)
        manuscript_page = ManuscriptViewerPage(self.getDriver())
        manuscript_page.page_ready()
        # Validate download drawer styles and actions
        manuscript_page.validate_download_drawer_styles()
        manuscript_page.validate_download_btn_actions()


if __name__ == '__main__':
    CommonTest.run_tests_randomly()
