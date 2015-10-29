import {
  moduleForComponent,
  test
} from 'ember-qunit';

import Ember from 'ember';

moduleForComponent('paper-sidebar', 'PaperSidebarComponent');

test('Returns submitted message when paper is submitted', function(assert) {
  assert.expect(2);

  let component = this.subject();
  this.render();

  // Assert initial content of the component
  let initialContent = $.trim(this.$().text());
  assert.equal(initialContent, '');

  Ember.run(function() {
    component.set('paper', {publishingState: 'submitted'});
  });

  let finalContent = $.trim(this.$().text());
  assert.equal(finalContent, 'This paper has been submitted.');
});

test('Shows submit if all task completed and submittable', function(assert) {
  assert.expect(1);

  let fakeSubmittableTask = Ember.Object.create({
    isSubmissionTask: true,
    completed: true,
    participations: []
  });

  let fakeSubmittablePaper = Ember.Object.create({
    publishingState: 'unsubmitted',
    tasks: [fakeSubmittableTask]
  });

  this.subject({paper: fakeSubmittablePaper});
  this.render();

  let buttonText = $.trim(this.$().find('button').text());
  assert.equal(buttonText, 'Submit');
});

test('Shows remaining tasks to complete message', function(assert) {
  assert.expect(1);

  let fakeSubmittableTask = Ember.Object.create({
    isSubmissionTask: true,
    completed: false,
    participations: []
  });

  let fakeSubmittablePaper = Ember.Object.create({
    publishingState: 'unsubmitted',
    tasks: [fakeSubmittableTask]
  });

  this.subject({paper: fakeSubmittablePaper});
  this.render();

  let msg = $.trim(this.$().text());
  assert.equal(msg, 'You must complete the following tasks before submitting:');
});