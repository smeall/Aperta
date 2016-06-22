#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
This test case validates the Title and Abstract Card
"""
import logging
import random
import time

from Base.Decorators import MultiBrowserFixture
from Base.Resources import users, editorial_users
from Cards.title_abstract_card import TitleAbstractCard
from frontend.common_test import CommonTest
from Pages.manuscript_viewer import ManuscriptViewerPage
from Pages.workflow_page import WorkflowPage
from Tasks.upload_manuscript_task import UploadManuscriptTask

__author__ = 'jgray@plos.org'


@MultiBrowserFixture
class TitleAbstractTest(CommonTest):
  """
  Tests the UI, styles, and functions, editing and saved display of the Title and Abstract Card
    of the workflow page. This card doesn't appear elsewhere.
  """
  def test_smoke_components_styles(self):
    creator = random.choice(users)
    journal = 'PLOS Yeti'
    logging.info('Logging in as user: {0}'.format(creator))
    dashboard_page = self.cas_login(email=creator['email'])
    # Create paper
    dashboard_page.click_create_new_submission_button()
    time.sleep(.5)
    paper_type = 'Research'
    logging.info('Creating Article in {0} of type {1}'.format(journal, paper_type))
    self.create_article(title='Testing Title and Abstract Card',
                        journal=journal,
                        type_=paper_type,
                        random_bit=True,
                        )
    paper_viewer = ManuscriptViewerPage(self.getDriver())
    # check for flash message
    paper_viewer.validate_ihat_conversions_success(timeout=15)
    paper_id = paper_viewer.get_current_url().split('/')[-1]
    paper_id = paper_id.split('?')[0] if '?' in paper_id else paper_id
    logging.info("Assigned paper id: {0}".format(paper_id))
    # paper_viewer.click_submit_btn()
    # paper_viewer.confirm_submit_btn()
    # paper_viewer.close_submit_overlay()
    # logout
    time.sleep(5)
    paper_viewer.logout()

    # log as editor - validate T&A Card
    staff_user = random.choice(editorial_users)
    logging.info('Logging in as user: {0}'.format(['name']))
    dashboard_page = self.cas_login(email=staff_user['email'])
    time.sleep(5)
    dashboard_page.go_to_manuscript(paper_id)
    self._driver.navigated = True
    paper_viewer = ManuscriptViewerPage(self.getDriver())
    time.sleep(5)
    # go to wf
    paper_viewer.click_workflow_link()
    workflow_page = WorkflowPage(self.getDriver())
    time.sleep(2)
    workflow_page.click_card('title_and_abstract')
    time.sleep(3)
    title_abstract = TitleAbstractCard(self.getDriver())
    title_abstract.validate_card_header(paper_id)
    title_abstract.validate_styles()
    title_abstract.check_initial_population(paper_id)
    title_abstract.click_completion_button()
    title_abstract.validate_common_elements_styles(paper_id)
    title_abstract.click_close_button()
    title_abstract.logout()

    # log back in as author to reupload MS
    dashboard_page = self.cas_login(email=creator['email'])
    time.sleep(5)
    dashboard_page.go_to_manuscript(paper_id)
    self._driver.navigated = True
    paper_viewer = ManuscriptViewerPage(self.getDriver())
    time.sleep(5)
    paper_viewer.click_task('upload_manuscript')
    time.sleep(3)
    upms = UploadManuscriptTask(self.getDriver())
    time.sleep(1)
    upms.click_completion_button()
    time.sleep(1)
    upms.upload_manuscript()
    upms.validate_ihat_conversions_success(timeout=30)
    upms.logout()

    # log back in as editor to validate T&A card state reset
    staff_user = random.choice(editorial_users)
    logging.info('Logging in as user: {0}'.format(['name']))
    dashboard_page = self.cas_login(email=staff_user['email'])
    time.sleep(5)
    dashboard_page.go_to_manuscript(paper_id)
    self._driver.navigated = True
    paper_viewer = ManuscriptViewerPage(self.getDriver())
    time.sleep(5)
    # go to wf
    paper_viewer.click_workflow_link()
    workflow_page = WorkflowPage(self.getDriver())
    time.sleep(2)
    workflow_page.click_card('title_and_abstract')
    time.sleep(3)
    title_abstract = TitleAbstractCard(self.getDriver())
    ta_state = title_abstract.completed_state()
    if ta_state:
      raise(AssertionError, 'Title and Abstract card state not reset on re-upload of manuscript')
    title_abstract.click_completion_button()
    new_ta_state = title_abstract.completed_state()
    time.sleep(1)
    if not new_ta_state:
      raise (AssertionError, 'Title and Abstract card state not in completed state')


if __name__ == '__main__':
  CommonTest._run_tests_randomly()
