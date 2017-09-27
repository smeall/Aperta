#!/usr/bin/env python
# -*- coding: utf-8 -*-

import json
import logging
import platform
import pytz
import random
import re
import tempfile
from time import sleep
import os
import time
import inspect

from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions
from selenium.webdriver.common.action_chains import ActionChains
from selenium.common.exceptions import TimeoutException, NoSuchElementException
from selenium.webdriver.common.keys import Keys
from bs4 import BeautifulSoup
import requests

from .CustomExpectedConditions import ElementToBeClickable
from .CustomException import ElementDoesNotExistAssertionError, ElementExistsAssertionError
from .LinkVerifier import LinkVerifier
from .Resources import local_tz
from .Config import wait_timeout, environment, base_url

__author__ = 'jkrzemien@plos.org'


class PlosPage(object):
  """
  Model an abstract base Journal page.
  """
  PROD_URL = ''
  logging.basicConfig(format='%(levelname)-s %(message)s [%(filename)s:%(lineno)d]',
                      level=logging.INFO)

  def __init__(self, driver, urlSuffix=''):
    # Internal WebDriver-related protected members
    self._driver = driver
    self._wait = WebDriverWait(self._driver, wait_timeout)
    self._actions = ActionChains(self._driver)

    base_url = self.__buildEnvironmentURL(urlSuffix)

    # Prevents WebDriver from navigating to a page more than once (there should be only one
    #   starting point for a test)
    if not hasattr(self._driver, 'navigated'):
      try:
        self._driver.get(base_url)
        self._driver.navigated = True
      except TimeoutException as toe:
        logging.error('\t[WebDriver Error] WebDriver timed out while trying to load the requested ' \

              'web page "{0}".'.format(base_url))
        raise toe

    # Internal private member
    self.__linkVerifier = LinkVerifier()

    # Locators - Instance variables unique to each instance
    self._article_type_menu = (By.ID, 'article-type-menu')

  # POM Actions

  def __buildEnvironmentURL(self, urlSuffix):
    """
    *Private* method to detect on which environment we are running the test.
    Then builds up a URL accordingly

    1. urlSuffix: String representing the suffix to append to the URL. It is generally provided by

    **Returns** A string representing the whole URL from where our test starts

    """
    env = environment.lower()
    baseurl = self.PROD_URL if env == 'prod' else base_url + urlSuffix
    return baseurl

  def _get(self, locator):
    try:
      return self._wait.until(expected_conditions.visibility_of_element_located(locator)).wrapped_element
    except TimeoutException:
      logging.error('\t[WebDriver Error] WebDriver timed out while trying to identify element ' \
            'by {0}.'.format(locator))
      raise ElementDoesNotExistAssertionError(locator)

  def _gets(self, locator):
    try:
      return [x.wrapped_element for x in self._wait.until(expected_conditions.presence_of_all_elements_located(locator))]
    except TimeoutException:
      logging.info('\t[WebDriver Error] WebDriver timed out while trying to identify elements ' \
            'by {0}.'.format(locator))
      raise ElementDoesNotExistAssertionError(locator)

  def _wait_on_lambda(self, wait_lambda, max_wait=30):
    """
    This is intended for use with lambdas having _gets or _get calls and therefore
    allows ElementDoesNotExistAssertionError's to occur and treats them the same
    as the lambda evaluating to false (continue wait).

     :param wait_lambda: lambda to evaluate every second, returning when it is true
     :param max_wait: maximum amount of time to wait for it to be true
    """
    for x in range(0, max_wait):
      saved_exception = None
      try:
        if wait_lambda():
          return
        else:
          time.sleep(1)
      except ElementDoesNotExistAssertionError as edneae:
        time.sleep(1)
        saved_exception = edneae

    if None is saved_exception:
      lambda_src = inspect.getsource(wait_lambda)
      raise TimeoutException('{0} not satisfied before {1} seconds passed'.format(lambda_src, max_wait))
    else:
      raise saved_exception

  def _iget(self, locator):
    """
    Unlike the regular _get() function, this one will be successful for elements with a width and
    or height of zero; stupid name, but suggesting 'i' for invisible as a zero width/height element.
    :param locator: locator
    """
    try:
      return self._wait.until(expected_conditions.presence_of_element_located(locator)).wrapped_element
    except TimeoutException:
      logging.error( '\t[WebDriver Error] WebDriver timed out while trying to identify element ' \
            'by {0}.'.format(locator))
      raise ElementDoesNotExistAssertionError(locator)

  def _check_for_invisible_element(self, locator):
    """
    Checks for the existence of an invisible element returning the element if it exists
    :param locator: the page element to check on
    :return: webdriver element or exception
    """
    try:
      return self._wait.until(expected_conditions.invisibility_of_element_located(locator)).wrapped_element
    except TimeoutException:
      logging.error( '\t[WebDriver Error] WebDriver timed out while trying to look for hidden element by ' \
            '{0}.'.format(locator))

      raise ElementDoesNotExistAssertionError(locator)

  def _check_for_invisible_element_boolean(self, locator):
    """
    Checks for the existence of an invisible element returning a boolean
    :param locator: the page element to check on
    :return: True if found, else False
    """
    self.set_timeout(2)
    try:
      self._wait.until(expected_conditions.invisibility_of_element_located(locator))
      return True
    except ElementDoesNotExistAssertionError:
      return False
    finally:
      self.restore_timeout()

  def _check_for_absence_of_element(self, locator):
    """
    Checks that an element doesn't exist
    :param locator: the page element to check on
    :return: True or Error
    """
    self.set_timeout(1)
    try:
      return self._wait.until_not(expected_conditions.visibility_of_element_located(locator))
    except TimeoutException:
      logging.error( '\t[WebDriver Error] Found element using {0} (test was for element ' \
            'absence).'.format(locator))
      raise ElementExistsAssertionError(locator)
    finally:
      self.restore_timeout()

  def _wait_for_element(self, element, multiplier=5):
    """
    We need a method that can be used to determine whether a page comprised of dynamic elements has
      fully loaded, or loaded enough to expose element.
    :param element: the item on a dynamic page we want to wait for
    :param multiplier: a multiplier, default (5) applied against the base wait_timeout to wait for
      element
    """
    timeout = wait_timeout * multiplier
    self.set_timeout(timeout)
    self._wait.until(ElementToBeClickable(element))
    self.restore_timeout()

  def _wait_for_text_be_present_in_element(self, locator, text,
                                           multiplier=5):
    """
    Wait for a string be present in an element text
    :param locator: the page locator of the element that should have the text
    :param text: text to be present in the located element
    :param multiplier: the multiplier of Config.wait_timeout to wait for a locator to be not present
    """
    timeout = wait_timeout * multiplier
    self.set_timeout(timeout)
    self._wait.until(expected_conditions.text_to_be_present_in_element(
      locator, text))
    self.restore_timeout()

  def _wait_for_not_element(self, locator, multiplier):
    """
    Waits for an element to go invisible or detach from the DOM
    :param locator: the page locator, not element, to check on
    :param multiplier: the multiplier of Config.wait_timeout to wait for a locator to be not present
    :return: True or Error
    """
    timeout = wait_timeout * multiplier
    self.set_timeout(timeout)
    try:
      return self._wait.until_not(expected_conditions.visibility_of_element_located(locator))
    except TimeoutException:
      logging.error( '\t[WebDriver Error] Found element using {0} (test was for element ' \

            'absence).'.format(locator))
      raise ElementExistsAssertionError(locator)
    finally:
      self.restore_timeout()

  def _is_link_valid(self, link):
    return self.__linkVerifier.is_link_valid(link.get_attribute('href'))

  def _scroll_into_view(self, element):
    self._driver.execute_script("javascript:arguments[0].scrollIntoView()", element)

  @staticmethod
  def normalize_spaces(text):
    """
    Helper method to leave strings with only one space between each word
    Used for string comparison when at least one string came from an HTML document
    :text: string
    :return: string
    """
    text = text.strip()
    # Replace non breakables spaces by spaces
    try:
      text = text.replace(u'\xa0', u' ')
    except UnicodeDecodeError:
      text = text.replace(u'\xa0', u' ')
    return re.sub(r'\s+', ' ', text)

  @staticmethod
  def compare_unicode(string_1, string_2):
    """
    Compare two string taking into account that there may be differente ammount of whitespaces
    Used to compare text taken from HTML.
    :string_1: Text string (may be Unicode or not)
    :string_2: Text string (may be Unicode or not)
    :return: True if compare is OK, is not, an assertion will fail
    """

    string_1 = PlosPage.normalize_spaces(string_1).split()
    string_2 = PlosPage.normalize_spaces(string_2).split()
    assert string_1 == string_2, \
      'String 1: {0} != String 2: {1}'.format(string_1, string_2)
    return True


  @staticmethod
  def get_random_bool():
    """
    Returns True of False when called.
    :return: True or False
    """
    choices = [True, False]
    outval = random.choice(choices)
    return outval

  def traverse_to_frame(self, frame):
    logging.info('\t[WebDriver] About to switch to frame "%s"...' % frame)
    self._wait.until(expected_conditions.frame_to_be_available_and_switch_to_it(frame))
    logging.info('OK')

  def traverse_from_frame(self):
    logging.info('\t[WebDriver] About to switch to default content...')
    self._driver.switch_to.default_content()
    logging.info('OK')

  def traverse_to_new_window(self):
    # Switch the last launched window
    logging.info('\t[WebDriver] About to switch the new window...')
    new_window = self._driver.window_handles[1]
    self._driver.switch_to_window(new_window)
    logging.info('OK')

  def traverse_from_window(self):
    # Return the the previous window
    logging.info('\t[WebDriver] About to switch to default content...')
    default_context = self._driver.window_handles[0]
    self._driver.switch_to_window(default_context)
    logging.info('OK')

  def set_timeout(self, new_timeout):
    self._driver.implicitly_wait(new_timeout)
    self._wait = WebDriverWait(self._driver, new_timeout)

  def restore_timeout(self):
    self._driver.implicitly_wait(wait_timeout)
    self._wait = WebDriverWait(self._driver, wait_timeout)

  def get_text(self, s):
    soup = BeautifulSoup(s, 'html.parser')
    clean_out = soup.get_text()
    return clean_out

  def open_new_tab(self):
    """Open a new tab"""
    opersys = platform.system()
    if opersys in ('Linux', 'Windows'):
      self._get((By.CSS_SELECTOR, 'body')).send_keys(Keys.CONTROL + 't')
    elif opersys == 'Darwin':
      self._get((By.CSS_SELECTOR, 'body')).send_keys(Keys.COMMAND + 't')
    return self

  def go_to_tab(self, tab_number):
    """Go to the requested tab"""
    self._get((By.CSS_SELECTOR, 'body')).send_keys(Keys.ALT + str(tab_number))
    return self

  def refresh(self):
    """Refreshes current page"""
    self._driver.refresh()
    return self

  def download_file(self, url, file_name=''):
    """
    Downloads a file from an URL. Is file_name is provided, will use this file name, is not,
    a unique unused file name will be generated and returned from the function.
    """
    r = requests.get(url, stream=True)
    if file_name:
      fh = open(os.path.join('/tmp/', file_name), 'wb')
    else:
      fh = tempfile.NamedTemporaryFile(mode='w+b', dir='/tmp', delete=False)
      file_name = fh.name
    for chunk in r.iter_content(chunk_size=1024):
      if chunk:
        fh.write(chunk)
        fh.flush()
    fh.close()
    return file_name

  def get_current_url(self):
    """
    Returns the url of the current page, with any trailing arguments, if present
    :return: url
    """
    url = self._driver.current_url
    return url

  def get_current_url_without_args(self):
    """
    Returns the url of the current page excluding any trailing arguments
    :return: url
    """
    url = self._driver.current_url
    if '?' in url:
      url = url.split('?')[0]
    return url

  def is_element_present(self, locator):
    """
    Checks for the presence of an element
    :param locator: the object to check on
    :return: boolean
    """
    try:
      self._driver.find_element(By.ID, locator)
      return True
    except NoSuchElementException:
      logging.error( '\t[WebDriver] Element {0} does not exist.'.format(locator))
      return False

  def wait_for_animation(self, selector):
    """
    A method for stalling during an animation event
    :param selector: the object to check on
    :return: void function
    """
    while self.is_element_animated(selector):
      sleep(.5)

  def is_element_animated(self, selector):
    """
    A javascript element to test for whether an object is animated
    :param selector:  the object to check on
    :return: boolean
    """
    return self._driver.execute_script(
        'return jQuery({0}).is(":animated");'.format(json.dumps(selector)))

  @staticmethod
  def utc_to_local_tz(utc_dto):
    """
    Takes a date time object in utc and converts it to the local timezone
    :param utc_dto: utc date time object
    :return: local_dto: converted local date time object
    """
    local_dto = utc_dto.replace(tzinfo=pytz.utc).astimezone(pytz.timezone(local_tz))
    return local_dto
