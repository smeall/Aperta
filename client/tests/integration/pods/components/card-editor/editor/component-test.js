import { moduleForComponent, test } from 'ember-qunit';
import { manualSetup, make } from 'ember-data-factory-guy';
import registerCustomAssertions from 'tahi/tests/helpers/custom-assertions';
import wait from 'ember-test-helpers/wait';
import hbs from 'htmlbars-inline-precompile';
import Ember from 'ember';

moduleForComponent(
  'card-editor/editor',
  'Integration | Component | card editor | editor',
  {
    integration: true,

    beforeEach() {
      registerCustomAssertions();
      manualSetup(this.container);
      this.registry.register(
        'pusher:main',
        Ember.Object.extend({ socketId: 'foo' })
      );
    },

    afterEach() {
      $.mockjax.clear();
    }
  }
);

test('publishing requires confirmation', function(assert) {
  assert.expect(4);
  let card = make('card', { state: 'draft' });
  this.set('card', card);

  $.mockjax({
    url: `/api/cards/${card.id}/publish`,
    method: 'PUT',
    status: 204
  });

  $.mockjax({
    url: `/api/cards/${card.id}`,
    method: 'GET',
    status: 200,
    responseText: {
      cards: [{ id: card.id }]
    }
  });
  this.render(
    hbs`
<div id='overlay-drop-zone'></div>
<div id='card-editor-action-buttons'></div>
{{card-editor/editor card=card}}`
  );

  assert.elementFound('.editor-publish');
  this.$('.editor-publish').click();
  assert.elementFound('.publish-card-overlay .button-primary');
  this.$('.publish-card-overlay .button-primary').click();

  return wait().then(() => {
    assert.mockjaxRequestMade(
      `/api/cards/${card.id}/publish`,
      'PUT',
      'it posts to publish the card'
    );
    assert.mockjaxRequestMade(
      `/api/cards/${card.id}`,
      'GET',
      'it reloads the card'
    );
  });
});

test('archiving requires confirmation', function(assert) {
  assert.expect(5);
  let card = make('card', { state: 'draft', journal: { id: 1 } });
  this.set('card', card);

  this.set('fakeRouting', {
    transitionTo(route, _whatever, queryParams) {
      assert.equal(
        route,
        'admin.cc.journals.cards',
        'transitions to the card catalog'
      );
      assert.equal(
        queryParams.journalID,
        1,
        `sets the query param to the card's journal id`
      );
    }
  });

  $.mockjax({
    url: `/api/cards/${card.id}/archive`,
    method: 'PUT',
    status: 204
  });

  $.mockjax({
    url: `/api/cards/${card.id}`,
    method: 'GET',
    status: 200,
    responseText: {
      cards: [{ id: card.id }]
    }
  });
  this.render(
    hbs`
<div id='overlay-drop-zone'></div>
<div id='card-editor-action-buttons'></div>
{{card-editor/editor card=card routing=fakeRouting}}`
  );

  assert.elementFound('.editor-archive[disabled]', 'archive is disabled for drafts');
  this.set('card.state', 'published');
  this.$('.editor-archive').click();
  assert.elementFound('.publish-card-overlay.archive .button-primary');
  this.$('.publish-card-overlay.archive .button-primary').click();

  return wait().then(() => {
    assert.mockjaxRequestMade(
      `/api/cards/${card.id}/archive`,
      'PUT',
      'it posts to archive the card'
    );
  });
});

test('saving is enabled when the card xml is dirty', function(assert) {
  let card = make('card', { state: 'draft', xml: 'Foo' });
  this.set('card', card);

  this.render(
    hbs`
<div id='card-editor-action-buttons'></div>
{{card-editor/editor card=card}}`
  );
  assert.elementFound(
    '.editor-save[disabled]',
    'the button is initially disabled'
  );
  this.set('card.xml', 'Bar');
  assert.ok(
    !$('.editor-save').attr('disabled'),
    'the button is enabled when the xml is dirty'
  );
});

test('deleting is disabled when the card xml is dirty', function(assert) {
  let card = make('card', { state: 'draft', xml: 'Foo' });
  this.set('card', card);

  this.render(
    hbs`
<div id='card-editor-action-buttons'></div>
{{card-editor/editor card=card}}`
  );
  assert.elementNotFound(
    '.editor-delete[disabled]',
    'the button is initially enabled'
  );
  this.set('card.xml', 'Bar');
  assert.ok(
    $('.editor-delete').attr('disabled'),
    'the button is disabled when the xml is dirty'
  );
});

test('deletion button is only present when the card is a draft', function(assert) {
  let card = make('card', { state: 'published' });
  this.set('card', card);

  this.render(
    hbs`
<div id='card-editor-action-buttons'></div>
{{card-editor/editor card=card}}`
  );
  assert.elementNotFound('.editor-delete',
                         'the delete button is not present when not a draft');

  this.set('card.state', 'draft');
  assert.elementFound('.editor-delete',
                      'the delete button is present when a draft');
});

test('deleting requires confirmation', function(assert) {
  assert.expect(4);
  let card = make('card', { state: 'draft', journal: { id: 1 } });
  this.set('card', card);

  this.set('fakeRouting', {
    transitionTo(route, _whatever, queryParams) {
      assert.equal(
        route,
        'admin.cc.journals.cards',
        'transitions to the card catalog'
      );
      assert.equal(
        queryParams.journalID,
        1,
        `sets the query param to the card's journal id`
      );
    }
  });

  $.mockjax({
    url: `/api/cards/${card.id}`,
    method: 'DELETE',
    status: 204
  });

  $.mockjax({
    url: `/api/cards/${card.id}`,
    method: 'GET',
    status: 200,
    responseText: {
      cards: [{ id: card.id }]
    }
  });
  this.render(
    hbs`
      <div id='overlay-drop-zone'></div>
      <div id='card-editor-action-buttons'></div>
      {{card-editor/editor card=card routing=fakeRouting}}`
  );

  this.$('.editor-delete').click();
  assert.elementFound('.publish-card-overlay.delete .button-primary');
  this.$('.publish-card-overlay.delete .button-primary').click();

  return wait().then(() => {
    assert.mockjaxRequestMade(
      `/api/cards/${card.id}`,
      'DELETE',
      'it deletes the card'
    );
  });
});
