import DS from 'ember-data';

export default DS.Model.extend({
  name: DS.attr('string'),
  category: DS.attr('string'),
  to: DS.attr('string'),
  subject: DS.attr('string'),
  body: DS.attr('string'),
  journalId: DS.attr('number'),
  mergeFields: DS.attr(),
  scenario: DS.attr('string'),
  cc: DS.attr('string'),
  bcc: DS.attr('string')
});
