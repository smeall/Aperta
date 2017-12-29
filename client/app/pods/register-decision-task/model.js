import Ember from 'ember';
import DS from 'ember-data';
import Task from 'tahi/pods/task/model';

const { attr } = DS;

export default Task.extend({
  decisionLetters: attr('string'),
  paperDecision: attr('string'),
  paperDecisionLetter: attr('string'),
  letterTemplates: DS.hasMany('letter-template', { async: false })
});
