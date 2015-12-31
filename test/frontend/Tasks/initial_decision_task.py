#!/usr/bin/env python2
# -*- coding: utf-8 -*-
import time

from selenium.webdriver.common.by import By
from selenium.webdriver.common.keys import Keys
from selenium.common.exceptions import NoSuchElementException

from frontend.Tasks.basetask import BaseTask

__author__ = 'sbassi@plos.org'

class InitialDecisionTask(BaseTask):
  """
  Page Object Model for Initial Decision task
  """

  data = ('Invite', 'placeholder text')

  def __init__(self, driver, url_suffix='/'):
    super(InitialDecisionTask, self).__init__(driver)


    #Locators - Instance members
    self._decisions = (By.CLASS_NAME, 'decision-selections')
    self._textarea = (By.TAG_NAME, 'textarea')
    self._register_btn = (By.TAG_NAME, 'button')

   #POM Actions
  def execute_decision(self, data=data):
    """
    This method completes XXXXXX
    :data: A tuple with the decision and the text to include in the decision
    """

    decision_d = {'Reject':0, 'Invite':1,}
    decision_labels =  self._get(self._decisions).find_elements_by_tag_name('label')
    ##import pdb; pdb.set_trace()
    decision_labels[decision_d[data[0]]].click()
    self._get(self._textarea).send_keys(data[1])
    # press "Register Decision" btn
    self._get(self._register_btn).click()
    # Give time to register the decision
    time.sleep(1)
    ##self._get(self._completed_cb).click()
    #task.click()

    return self
