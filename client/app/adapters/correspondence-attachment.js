import Ember from 'ember';
import ApplicationAdapter from 'tahi/adapters/application';

export default ApplicationAdapter.extend({
  buildURL: function(modelName, id, record) {
    let correspondenceId = record.belongsTo('correspondence').id;
    Ember.assert(`Expected a correspondence.id but didn't find one`, correspondenceId);

    let paperId = record.belongsTo('correspondence').belongsTo('paper').id;
    Ember.assert(`Expected a paper.id but didn't find one`, paperId);

    let namespace = this.get('namespace');
    if (namespace) {
      namespace = `/${namespace}`;
    } else {
      namespace = '';
    }

    let url = `${namespace}/papers/${paperId}/correspondence/${correspondenceId}/attachments`;

    if (id) {
      url = `${url}/${id}`;
    }

    return url;
  }
});