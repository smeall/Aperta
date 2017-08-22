import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';
import FactoryGuy from 'ember-data-factory-guy';
import { manualSetup } from 'ember-data-factory-guy';
import sinon from 'sinon';
import Ember from 'ember';
import {getRichText, setRichText} from 'tahi/tests/helpers/rich-text-editor-helpers';
import wait from 'ember-test-helpers/wait';

moduleForComponent('admin-page/email-templates/edit',
  'Integration | Component | Admin Page | Email Templates | Edit', {
    integration: true,
    beforeEach() {
      manualSetup(this.container);
    }
  }
);

test('it populates input fields with model data', function(assert) {
  assert.expect(2);

  let template = FactoryGuy.make('letter-template', {subject: 'foo', body: '<p>bar</p>'});

  this.set('template', template);

  this.render(hbs`
    {{admin-page/email-templates/edit template=template}}
  `);
  assert.equal(this.$('#subject').val(), template.get('subject'));
  assert.equal(getRichText('body'), template.get('body'));
});

test('it prevents the model from saving if a field is blank and displays validation errors', function(assert){
  assert.expect(2);

  let template = FactoryGuy.make('letter-template', {subject: '', body: 'bar'});
  sinon.spy(template, 'save');
  this.set('template', template);

  this.render(hbs`
    {{admin-page/email-templates/edit template=template}}
  `);

  Ember.run(() => {
    this.$('.button-primary').click();
  });
  assert.elementFound('.form-group.error');
  assert.equal(template.save.called, false);
});

test('model receives save call when valid', function(assert){
  assert.expect(1);

  let template = FactoryGuy.make('letter-template', {subject: 'foo', body: ''});
  var saveStub = sinon.stub(template, 'save');

  // Reject the promise because routing isnt working here, this is easier.
  saveStub.returns(Ember.RSVP.Promise.reject());

  this.set('template', template);

  this.render(hbs`
    {{admin-page/email-templates/edit template=template}}
  `);

  setRichText('body', 'text');

  let done = assert.async();
  wait().then(() => {
    this.$('.button-primary').click();
    assert.ok(template.save.called);
    done();
  });
});

test('after attempted save it dynamically warns user if input field has invalid content', function(assert) {
  assert.expect(2);

  let template = FactoryGuy.make('letter-template', {subject: '', body: 'bar'});
  this.set('template', template);

  this.render(hbs`
    {{admin-page/email-templates/edit template=template}}
  `);

  Ember.run(() => {
    this.$('.button-primary').click();
    this.$('#subject').val('wat').trigger('input');
  });

  assert.elementNotFound('.error');

  Ember.run(() => {
    this.$('#subject').val('').trigger('input');
  });
  assert.elementFound('.error');
});
