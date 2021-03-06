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
import { createQuestion, createQuestionWithAnswer } from 'tahi/tests/factories/nested-question';
import registerCustomAssertions from 'tahi/tests/helpers/custom-assertions';
import FakeCanService from 'tahi/tests/helpers/fake-can-service';
import Ember from 'ember';
import wait from 'ember-test-helpers/wait';

moduleForComponent('nested-question-input', 'Integration | Component | nested question input', {
  integration: true,
  beforeEach() {
    registerCustomAssertions();
    manualSetup(this.container);
    this.registry.register('service:pusher', Ember.Object.extend({socketId: 'foo'}));
    this.registry.register('service:can', FakeCanService);

    this.getAnswers = function() {
      return this.container.lookup('service:store').peekAll('nested-question-answer');
    };
  },

  afterEach() {
    $.mockjax.clear();
  }
});

let setValue = ($input, newVal) => {
  return $input.val(newVal).trigger('input');
};

test('it puts a new answer in the store for unanswered questions, then saves on input', function(assert) {
  let task =  make('ad-hoc-task');
  let fake = this.container.lookup('service:can');
  fake.allowPermission('edit', task);
  let question = createQuestion(task, 'foo');
  this.set('task', task);
  this.render(hbs`
    {{nested-question-input ident="foo" owner=task}}
  `);

  let newAnswer = this.getAnswers().get('firstObject');
  assert.ok(newAnswer.get('isNew'), 'there is a new answer in the store');
  assert.equal(newAnswer.get('owner.id'), task.id, 'the new answer belongs to the task');
  assert.equal(newAnswer.get('nestedQuestion.id'), question.id, 'the new answer belongs to the question');

  $.mockjax({url: '/api/nested_questions/1/answers', type: 'POST', status: 201, responseText: {nested_question_answer: {id: 5}}});
  setValue(this.$('input'), 'new value');
  return wait().then(() => {
    assert.mockjaxRequestMade('/api/nested_questions/1/answers', 'POST', 'it saves the new answer on change');
  });
});

test('it saves an existing answer on input', function(assert) {
  let task =  make('ad-hoc-task');
  let fake = this.container.lookup('service:can');
  fake.allowPermission('edit', task);
  createQuestionWithAnswer(task, 'foo', 'Old Answer');
  this.set('task', task);
  this.render(hbs`
    {{nested-question-input ident="foo" owner=task}}
  `);

  assert.equal(this.$('input').val(), 'Old Answer', 'it renders the answer');

  let answer = this.getAnswers().get('firstObject');
  assert.notOk(answer.get('isNew'), 'the answer is not new');

  $.mockjax({url: '/api/nested_questions/1/answers/1', type: 'PUT', status: 204, responseText: ''});
  setValue(this.$('input'), 'new value');
  return wait().then(() => {
    assert.mockjaxRequestMade('/api/nested_questions/1/answers/1', 'PUT', 'it saves the new answer on change');
  });
});

test('it deletes and replaces the existing answer on input if the answer is blank', function(assert) {
  let task =  make('ad-hoc-task');
  let fake = this.container.lookup('service:can');
  fake.allowPermission('edit', task);
  createQuestionWithAnswer(task, 'foo', 'Old Answer');
  this.set('task', task);
  this.render(hbs`
    {{nested-question-input ident="foo" owner=task}}
  `);

  $.mockjax({url: '/api/nested_questions/1/answers/1', type: 'DELETE', status: 204, responseText: ''});
  setValue(this.$('input'), '');
  return wait().then(() => {
    assert.mockjaxRequestMade('/api/nested_questions/1/answers/1', 'DELETE', 'deletes the blank answer');
    assert.equal(this.getAnswers().get('length'), 1, 'there is only one answer in the store');
    let answer = this.getAnswers().get('firstObject');
    assert.ok(answer.get('isNew'), 'the answer is new');

    $.mockjax.clear();
    $.mockjax({
      url: /api\/nested_questions\/\d+\/answers/,
      type: 'POST',
      status: 201,
      response() {
        let id = 'testId' + Math.random();
        this.responseText = { nested_question_answer: { id } };
      }
    });

    setValue(this.$('input'), 'really new answer');
  }).then(wait)
  .then(() => {
    assert.mockjaxRequestMade('/api/nested_questions/1/answers', 'POST', 'it saves the new answer on change');
  });
});

test('it does not render when the type is invalid', function(assert) {
  let task =  make('ad-hoc-task');
  let fake = this.container.lookup('service:can');
  fake.allowPermission('edit', task);
  createQuestionWithAnswer(task, 'foo', 'Old Answer');
  this.set('task', task);
  return assert.throws(() => {
    this.subject(hbs`
      {{nested-question-input ident="foo" owner=task type="radio"}}
    `);
  });
});
