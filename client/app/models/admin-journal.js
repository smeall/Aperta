import DS from 'ember-data';

export default DS.Model.extend({
  manuscriptManagerTemplates: DS.hasMany('manuscriptManagerTemplate'),
  roles: DS.hasMany('role'),
  journalTaskTypes: DS.hasMany('journalTaskType'),

  createdAt: DS.attr('date'),
  description: DS.attr('string'),
  doi: DS.attr(),
  doiJournalPrefix: DS.attr('string'),
  doiPublisherPrefix: DS.attr('string'),
  epubCoverFileName: DS.attr('string'),
  epubCoverUrl: DS.attr('string'),
  epubCss: DS.attr('string'),
  lastDoiIssued: DS.attr('number'),
  logoUrl: DS.attr('string'),
  manuscriptCss: DS.attr('string'),
  name: DS.attr('string'),
  paperCount: DS.attr('number'),
  paperTypes: DS.attr(),
  pdfCss: DS.attr('string')
});
