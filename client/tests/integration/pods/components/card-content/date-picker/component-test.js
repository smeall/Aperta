import { moduleForComponent, test } from 'ember-qunit';
import hbs from 'htmlbars-inline-precompile';
import registerCustomAssertions from 'tahi/tests/helpers/custom-assertions';
import Ember from 'ember';

moduleForComponent(
  'card-content/date-picker',
  'Integration | Component | card content | date picker',
  {
    integration: true,
    beforeEach() {
      registerCustomAssertions();
      this.set('actionStub', function() {});
      this.set('content', Ember.Object.create({ ident: 'test' }));
      this.set('answer', Ember.Object.create({ value: null }));
    }
  }
);

let template = hbs`{{card-content/date-picker
answer=answer
content=content
disabled=disabled
valueChanged=(action actionStub)
}}`;

test(`it displays content.text as unescaped html in a <p>`, function(assert) {
  this.set('content', Ember.Object.create({ text: '<b class="foo">Foo</b>' }));

  this.render(template);
  assert.elementFound('.card-content-date-picker b.foo');
});

test(`it renders a date picker with a title`, function(assert) {
  this.set('content', Ember.Object.create({ text: 'Title' }));

  this.render(template);
  assert.equal($('h3.picker-title').html(), 'Title');
  assert.elementFound('input.datepicker');
});

test('includes the ident in the name and id if present', function(assert) {
  this.set('content', Ember.Object.create({ ident: 'test' }));
  this.render(template);
  assert.equal(this.$('input').attr('name'), 'date-picker-test');
});

// test(`it sends 'valueChanged' on change`, function(assert) {
//   assert.expect(1);
//   this.set('actionStub', function(newVal) {
//     assert.equal(newVal, true, 'it calls the action with the new value');
//   });
//   this.render(template);
//   this.$('input').click();
//   assert.async()
// });
