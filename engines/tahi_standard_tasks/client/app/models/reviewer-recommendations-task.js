import DS   from 'ember-data';
import Task from 'tahi/models/task';

export default Task.extend({
  reviewerRecommendations: DS.hasMany('reviewerRecommendation'),
  institutionNames: DS.attr('string'),
  institutions: function() {
    return (this.get('institutionNames').split(',')).map(function(institution) {
      return { id: institution, text: institution };
    });
  }.property('institutionNames')
});
