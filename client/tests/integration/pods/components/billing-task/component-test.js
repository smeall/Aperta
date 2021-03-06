/**
 * Copyright (c) 2018 Public Library of Science
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
*/

import { test, moduleForComponent } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';
import { manualSetup, make } from 'ember-data-factory-guy';
import {
  createQuestionWithAnswer
} from 'tahi/tests/factories/nested-question';
import registerCustomAssertions from 'tahi/tests/helpers/custom-assertions';
import Factory from 'tahi/tests/helpers/factory';
import Ember from 'ember';
import wait from 'ember-test-helpers/wait';

moduleForComponent('billing-task', 'Integration | Component | billing task', {
  integration: true,
  beforeEach() {
    registerCustomAssertions();
    manualSetup(this.container);

    this.registry.register(
      'service:pusher',
      Ember.Object.extend({ socketId: 'foo' })
    );
    $.mockjax({
      url: '/api/countries',
      status: 200,
      responseText: {
        countries: []
      }
    });
    $.mockjax({
      url: '/api/institutional_accounts',
      status: 200,
      responseText: {
        institutional_accounts: []
      }
    });
    Factory.createPermission('billingTask', 1, ['edit', 'view']);
  },
  afterEach() {
    $.mockjax.clear();
  }
});

let template = hbs`{{billing-task task=testTask}}`;

let createTask = function() {
  return make('billing-task');
};

// for readability
let createInvalidTask = function() {
  return createTask();
};

let createValidTask = function() {
  let task = createTask();
  fillInBasicBillingInfoForTask(task);
  return task;
};

let fillInBasicBillingInfoForTask = function(task) {
  createQuestionWithAnswer(task, 'plos_billing--first_name', 'John');
  createQuestionWithAnswer(task, 'plos_billing--last_name', 'Doe');
  createQuestionWithAnswer(task, 'plos_billing--title', 'Prof');
  createQuestionWithAnswer(task, 'plos_billing--department', 'Fun');
  createQuestionWithAnswer(task, 'plos_billing--affiliation1', 'Some Uni');
  createQuestionWithAnswer(task, 'plos_billing--affiliation2', 'Another Uni');
  createQuestionWithAnswer(task, 'plos_billing--phone_number', '123-335-1223');
  createQuestionWithAnswer(task, 'plos_billing--email', 'foo@bar.com');
  createQuestionWithAnswer(task, 'plos_billing--address1', '101 foo st.');
  createQuestionWithAnswer(task, 'plos_billing--address2', '');
  createQuestionWithAnswer(task, 'plos_billing--city', 'Columbus');
  createQuestionWithAnswer(task, 'plos_billing--state', 'OH');
  createQuestionWithAnswer(task, 'plos_billing--postal_code', 12345);
  createQuestionWithAnswer(task, 'plos_billing--country', 'USA');
  createQuestionWithAnswer(task, 'plos_billing--payment_method', 'pfa');
  createQuestionWithAnswer(task, 'plos_billing--pfa_question_1', true);
  createQuestionWithAnswer(task, 'plos_billing--pfa_question_1a', 'foo');
  createQuestionWithAnswer(task, 'plos_billing--pfa_question_2', true);
  createQuestionWithAnswer(task, 'plos_billing--pfa_question_2a', '');
  createQuestionWithAnswer(task, 'plos_billing--pfa_question_3', true);
  createQuestionWithAnswer(task, 'plos_billing--pfa_question_4', true);
  createQuestionWithAnswer(task, 'plos_billing--pfa_amount_to_pay', '99.00');
  createQuestionWithAnswer(task, 'plos_billing--pfa_supporting_docs', 'foo');
  createQuestionWithAnswer(
    task,
    'plos_billing--pfa_additional_comments',
    'foo'
  );
  createQuestionWithAnswer(
    task,
    'plos_billing--affirm_true_and_complete',
    false
  );
};

test('validates numericality of a few fields', function(assert) {
  let testTask = createValidTask();
  this.set('testTask', testTask);

  fillInBasicBillingInfoForTask(testTask);

  this.set('task', testTask);
  this.render(template);

  // filling in a nested question's text input and firing input()
  // will bubble up to the nested question radio, and both will save.
  $.mockjax({ url: /\/api\/nested_questions/, type: 'PUT', status: 204 });
  $.mockjax({
    url: /\/api\/nested_questions/,
    type: 'POST',
    status: 201,
    response() {
      let id = 'testId' + Math.random();
      this.responseText = { nested_question_answer: { id } };
    }
  });

  // Make the PFA questions invalid
  this.$('input[name=plos_billing--pfa_question_1b]')
    .val('not a number')
    .trigger('input');
  this.$('input[name=plos_billing--pfa_question_2b]')
    .val('not a number')
    .trigger('input');
  this.$('input[name=plos_billing--pfa_question_3a]')
    .val('not a number')
    .trigger('input');
  this.$('input[name=plos_billing--pfa_question_4a]')
    .val('not a number')
    .trigger('input');

  return wait().then(() => {
    assert.textPresent(
      '#error-for-plos_billing--pfa_question_1b',
      'Must be a number'
    );
    assert.textPresent(
      '#error-for-plos_billing--pfa_question_2b',
      'Must be a number'
    );
    assert.textPresent(
      '#error-for-plos_billing--pfa_question_3a',
      'Must be a number'
    );
    assert.textPresent(
      '#error-for-plos_billing--pfa_question_4a',
      'Must be a number'
    );
  });
});

test('it reports validation errors on the task when attempting to complete', function(
  assert
) {
  let testTask = createTask();
  this.set('testTask', testTask);
  this.render(template);
  this.$('.billing-task button.task-completed').click();

  return wait().then(() => {
    // Error at the task level
    assert.textPresent('.billing-task', 'Please fix all errors');
  });
});

test('it does not allow the user to complete when there are validation errors', function(
  assert
) {
  let testTask = createTask();
  this.set('testTask', testTask);
  this.render(template);
  this.$('.billing-task button.task-completed').click();

  return wait().then(() => {
    assert.equal(testTask.get('completed'), false, 'task remained incomplete');
  });
});

test('it lets you complete the task when there are no validation errors', function(
  assert
) {
  let testTask = createValidTask();
  this.set('testTask', testTask);

  $.mockjax({
    url: '/api/tasks/1',
    type: 'PUT',
    status: 204,
    responseText: '{}'
  });
  this.render(template);

  // try to complete
  this.$('.billing-task button.task-completed').click();

  return wait().then(() => {
    assert.equal(testTask.get('completed'), true, 'task was completed');
    assert.mockjaxRequestMade('/api/tasks/1', 'PUT');
  });
});

test('it lets you uncomplete the task when it has validation errors', function(
  assert
) {
  let testTask = createInvalidTask();
  this.set('testTask', testTask);

  Ember.run(() => {
    testTask.set('completed', true);
  });

  $.mockjax({
    url: '/api/tasks/1',
    type: 'PUT',
    status: 204,
    responseText: '{}'
  });
  this.render(template);

  assert.equal(testTask.get('completed'), true, 'task was initially completed');
  this.$('.billing-task button.task-completed').click();

  return wait().then(() => {
    assert.equal(
      testTask.get('completed'),
      false,
      'task was marked as incomplete'
    );
    assert.mockjaxRequestMade('/api/tasks/1', 'PUT');
    $.mockjax.clear();

    // try complete again
    this.$('.billing-task button.task-completed').click();

    wait().then(() => {
      assert.textPresent('.billing-task', 'Please fix all errors');
      assert.equal(
        testTask.get('completed'),
        false,
        'task did not input completion status'
      );
      assert.mockjaxRequestNotMade('/api/tasks/1', 'PUT');
    });
  });
});
