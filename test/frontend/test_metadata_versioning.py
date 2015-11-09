#!/usr/bin/env python2
# -*- coding: utf-8 -*-
"""
This test case validates metadata versioning for Aperta.
"""
__author__ = 'sbassi@plos.org'

import time

from selenium.common.exceptions import NoAlertPresentException

from Base.Decorators import MultiBrowserFixture
from Cards.basecard import BaseCard
from Cards.register_decision_card import RegisterDecisionCard
from frontend.common_test import CommonTest
from Pages.dashboard import DashboardPage
from Pages.manuscript_viewer import ManuscriptViewerPage
from Pages.workflow_page import WorkflowPage


@MultiBrowserFixture
class MetadataVersioningTest(CommonTest):
  """
  Since metadata versioning is not developed yet, this calls create condition
  for testing by creating an article, filling all required cards, submitting.
  """
  def _test_metadata_versioning(self):
    """
    Test metadata versioning (APERTA-3368).
    AC:
     - Version information
     - add/edit/delete functionality disabled
    Since this task is not completed, this test is disabled until the functionality is in place.
    """
    title = 'For metadata versioning'
    #if True: # for debugging
    if self.check_article(title):
      init = True if 'users/sign_in' in self._driver.current_url else False
      article = self.select_preexisting_article(title=title, init=init)
    else:
      # Create new article
      title = self.create_article(title=title,
                                 journal='PLOS Lemur',
                                 type_='Research',
                                 random_bit=True,
                                 init=False)
    paper_viewer = ManuscriptViewerPage(self.getDriver())
    paper_viewer.complete_card('Billing')
    paper_viewer.complete_card('Authors')
    paper_viewer.complete_card('Cover Letter')
    paper_viewer.complete_card('Figures')
    paper_viewer.complete_card('Supporting Info')
    paper_viewer.complete_card('Upload Manuscript')
    # Click submit
    paper_viewer.press_submit_btn()
    paper_viewer.confirm_submit_btn()
    paper_viewer.close_submit_overlay()
    # go to workflow
    paper_viewer.click_workflow_lnk()
    workflow_page = WorkflowPage(self.getDriver())
    # press register decision
    workflow_page._get(workflow_page._register_decision_button).click()
    # register decision (major)
    register_decision_card = RegisterDecisionCard(self.getDriver())
    register_decision_card.register_decision('Major Revision')
    time.sleep(1)
    # manuscript
    workflow_page._get(workflow_page._manuscript_link).click()
    time.sleep(1)
    paper_viewer = ManuscriptViewerPage(self.getDriver())
    time.sleep(1)
    # TODO: file a bug about the need for refresh this
    paper_viewer.refresh()
    alert = self._driver.switch_to_alert()
    try:
      alert.accept()
    except NoAlertPresentException:
      # Sometimes there is no alert on this operationm in thise case, do nothing
      pass
    time.sleep(1)
    # TODO: Upload image
    paper_viewer.complete_card('Revise Manuscript')
    time.sleep(1)
    # TODO: Submit again
    return self


if __name__ == '__main__':
  CommonTest._run_tests_randomly()
