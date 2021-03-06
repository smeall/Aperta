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

import Ember from 'ember';
import { test } from 'qunit';
import { make } from 'ember-data-factory-guy';
import Factory from 'tahi/tests/helpers/factory';
import * as TestHelper from 'ember-data-factory-guy';
import moduleForAcceptance from 'tahi/tests/helpers/module-for-acceptance';

const { mockCreate, mockFindRecord } = TestHelper;

let paper, topic;

moduleForAcceptance('Integration: Discussions', {
  beforeEach() {
    paper = make('paper_with_discussion', { phases: [], tasks: [] });
    topic = make(
      'topic_with_replies',
      { paperId: paper.id, title: 'Hipster Ipsum Dolor' });

    $.mockjax({
      url: '/api/at_mentionable_users',
      type: 'GET',
      status: 200,
      contentType: 'application/json',
      responseText: {
        users: [{id: 1, full_name: 'Charmander', email: 'fire@oak.edu'}]
      }
    });

    var paperResponse = paper.toJSON();
    paperResponse.id = 1;

    $.mockjax({
      url: '/api/papers/' + paperResponse.shortDoi,
      status: 200,
      responseText: {
        paper: paperResponse
      }
    });

    $.mockjax({url: '/api/admin/journals/authorization', status: 204});
    $.mockjax({url: /\/api\/papers\/\d+\/manuscript_manager/, status: 204});
    $.mockjax({url: /\/api\/journals/, type: 'GET', status: 200, responseText: { journals: [] }});

    mockFindRecord('paper').returns({ model: paper });
    TestHelper.mockFindAll('discussion-topic', 1);

    Factory.createPermission('Paper', paper.id, ['manage_workflow', 'start_discussion']);

    const restless = this.application.__container__.lookup('service:restless');
    restless['delete'] = function() {
      return Ember.RSVP.resolve({});
    };
  }
});

test('can see a list of topics', function(assert) {
  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });

    visit('/papers/' + paper.id + '/workflow/discussions/');

    andThen(function() {
      const firstTopic = find('.discussions-index-topic:first');
      assert.ok(firstTopic.length, 'Topic is found: ' + firstTopic.text());
    });
  });
});

test('can see a list of topics for /discussions', function(assert) {
  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });

    visit('/discussions/' + paper.id);

    andThen(function() {
      const firstTopic = find('.discussions-index-topic:first');
      assert.ok(firstTopic.length, 'Topic is found: ' + firstTopic.text());
    });
  });
});

test('cannot create discussion without title', function(assert) {
  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });
    visit('/papers/' + paper.id + '/workflow/discussions/new');
    click('#create-topic-button');

    andThen(function() {
      const titleFieldContainer = find('#topic-title-field').parent();
      assert.ok(titleFieldContainer.hasClass('error'), 'Error is displayed');
    });
  });
});

test('cannot create discussion without title for /discussions', function(assert) {
  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });

    visit('/discussions/' + paper.id + '/new');
    click('#create-topic-button');

    andThen(function() {
      const titleFieldContainer = find('#topic-title-field').parent();
      assert.ok(titleFieldContainer.hasClass('error'), 'Error is displayed');
    });
  });
});

test('can see a non-editable topic with view permissions', function(assert) {
  Factory.createPermission('DiscussionTopic', 1, ['view']);

  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });
    visit('/papers/' + paper.id + '/workflow/discussions/' + topic.get('id'));

    andThen(function() {
      const titleText = find('.discussions-show-title').text().trim();
      assert.equal(titleText, 'Hipster Ipsum Dolor', 'Topic title is found: ' + titleText);
    });
  });
});

test('can see a non-editable topic with view permissions for /discussions', function(assert) {
  Factory.createPermission('DiscussionTopic', 1, ['view']);

  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });

    visit('/discussions/' + paper.id + '/' + topic.get('id'));
    andThen(function() {
      const titleText = find('.discussions-show-title').text().trim();
      assert.equal(titleText, 'Hipster Ipsum Dolor', 'Topic title is found: ' + titleText);
    });

  });
});

test('can reply to a topic with view permissions', function(assert) {
  const replyText = 'test';
  const topicScreen = '/papers/' + paper.id + '/workflow/discussions/' + topic.get('id');

  Factory.createPermission('DiscussionTopic', 1, ['view']);
  mockFindRecord('discussion-topic').returns({ model: topic });
  mockCreate('discussion-reply');

  visit(topicScreen).then(function() {
    triggerEvent(find('.new-comment-field'), 'focus').then(function() {
      find('.new-comment-field').val(replyText).trigger('change');
      return triggerEvent(find('.new-comment-submit-button'), 'click');
    });
  });

  andThen(function() {
    const text = $('.message-comment:last .comment-body').text();
    assert.equal(text, replyText, 'Reply is found');
  });
});

test('can reply to a topic with view permissions for /discussions', function(assert) {
  const replyText = 'test';
  const topicScreen = '/discussions/' + paper.id + '/' + topic.get('id');

  Factory.createPermission('DiscussionTopic', 1, ['view']);
  mockFindRecord('discussion-topic').returns({ model: topic });
  mockCreate('discussion-reply');

  visit(topicScreen).then(function() {
    triggerEvent(find('.new-comment-field'), 'focus').then(function() {
      find('.new-comment-field').val(replyText).trigger('change');
      return triggerEvent(find('.new-comment-submit-button'), 'click');
    });
  });

  andThen(function() {
    const text = $('.message-comment:last .comment-body').text();
    assert.equal(text, replyText, 'Reply is found');
  });
});

test('reply is cached if unsaved', function(assert) {
  const topicScreen = '/papers/' + paper.id + '/workflow/discussions/' + topic.get('id');
  const replyText = 'test';

  Factory.createPermission('DiscussionTopic', 1, ['view']);
  mockFindRecord('discussion-topic').returns({ model: topic });

  visit(topicScreen).then(function() {
    find('.new-comment-field').val(replyText).trigger('keyup');
    find('.sheet-toolbar-button').click();
  });

  visit(topicScreen);

  andThen(function() {
    assert.equal(find('.new-comment-field').val(), replyText, 'Text cached');
  });
});

test('reply is cached if unsaved for /discussions', function(assert) {
  const topicScreen = '/discussions/' + paper.id + '/' + topic.get('id');
  const replyText = 'test';

  Factory.createPermission('DiscussionTopic', 1, ['view']);
  mockFindRecord('discussion-topic').returns({ model: topic });

  visit(topicScreen).then(function() {
    find('.new-comment-field').val(replyText).trigger('keyup');
    find('.sheet-toolbar-button').click();
  });

  visit(topicScreen);

  andThen(function() {
    assert.equal(find('.new-comment-field').val(), replyText, 'Text cached');
  });
});

test('comment body line returns converted to break tags', function(assert) {
  Factory.createPermission('DiscussionTopic', 1, ['view']);

  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });
    visit('/papers/' + paper.id + '/workflow/discussions/' + topic.get('id'));

    andThen(function() {
      const replyText = find('.comment-body:first').html();
      assert.equal(replyText, 'hey<br>how are you?', 'break tags found');
    });
  });
});

test('comment body line returns converted to break tags for /discussions', function(assert) {
  Factory.createPermission('DiscussionTopic', 1, ['view']);

  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });
    visit('/discussions/' + paper.id + '/' + topic.get('id'));

    andThen(function() {
      const replyText = find('.comment-body:first').html();
      assert.equal(replyText, 'hey<br>how are you?', 'break tags found');
    });

  });
});

test('can see an editable topic with edit permissions', function(assert) {
  Factory.createPermission('DiscussionTopic', 1, ['view', 'edit']);

  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });
    visit('/papers/' + paper.id + '/workflow/discussions/' + topic.get('id'));

    andThen(function() {
      const titleText = find('.discussions-show-title input').val();
      assert.equal(titleText, 'Hipster Ipsum Dolor', 'Topic title is found: ' + titleText);
    });
  });
});

test('can see an editable topic with edit permissions for /discussions', function(assert) {
  Factory.createPermission('DiscussionTopic', 1, ['view', 'edit']);

  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });
    visit('/discussions/' + paper.id + '/' + topic.get('id'));

    andThen(function() {
      const titleText = find('.discussions-show-title input').val();
      assert.equal(titleText, 'Hipster Ipsum Dolor', 'Topic title is found: ' + titleText);
    });
  });
});

test('cannot persist empty title', function(assert) {
  Factory.createPermission('DiscussionTopic', 1, ['view', 'edit']);

  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });
    visit('/papers/' + paper.id + '/workflow/discussions/' + topic.get('id'));

    andThen(function() {
      const titleFieldSelector = '.discussions-show-title input';
      const titleField = find(titleFieldSelector);
      const titleFieldContainer = find('.discussions-show-title');

      fillIn(titleFieldSelector, '');

      triggerEvent(titleField, 'blur').then(()=> {
        assert.ok(titleFieldContainer.hasClass('error'), 'Error is displayed on title');
      });
    });
  });
});

test('cannot persist empty title for /discussions', function(assert) {
  Factory.createPermission('DiscussionTopic', 1, ['view', 'edit']);

  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });
    visit('/discussions/' + paper.id + '/' + topic.get('id'));

    andThen(function() {
      const titleFieldSelector = '.discussions-show-title input';
      const titleField = find(titleFieldSelector);
      const titleFieldContainer = find('.discussions-show-title');

      fillIn(titleFieldSelector, '');

      triggerEvent(titleField, 'blur').then(()=> {
        assert.ok(titleFieldContainer.hasClass('error'), 'Error is displayed on title');
      });
    });
  });
});

test('pops out discussions', function(assert){
  Ember.run(function() {
    mockFindRecord('discussion-topic').returns({ model: topic });

    visit('/papers/' + paper.id + '/workflow/discussions/');

    andThen(function() {
      const firstTopic = find('.discussions-index-topic:first');
      assert.ok(firstTopic.length, 'Topic is found: ' + firstTopic.text());
    });
  });
});
