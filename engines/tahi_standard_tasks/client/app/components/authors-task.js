import Ember from 'ember';
import TaskComponent from 'tahi/pods/components/task-base/component';
import ObjectProxyWithErrors from 'tahi/models/object-proxy-with-validation-errors';
import validations from 'tahi/authors-task-validations';

const { computed, on } = Ember;

export default TaskComponent.extend({
  newAuthorFormVisible: false,

  validateData() {
    const objs = this.get('sortedAuthorsWithErrors');
    objs.invoke('validateAllKeys');

    const errors = ObjectProxyWithErrors.errorsPresentInCollection(objs);

    if(errors) {
      this.set('validationErrors.completed', 'Please fix all errors');
    }
  },

  authors: computed('task.authors.@each.paper', function() {
    return this.get('task.authors').filterBy('paper', this.get('paper'));
  }),

  authorSort: ['position:asc'],
  sortedAuthors: computed.sort('task.authors', 'authorSort'),
  sortedAuthorsWithErrors: computed('sortedAuthors.[]', function() {
    return this.get('sortedAuthors').map(function(a) {
      return ObjectProxyWithErrors.create({
        object: a,
        validations: validations
      });
    });
  }),

  nestedQuestionsForNewAuthor: Ember.A(),
  newAuthorQuestions: on('init', function(){
    const q = { type: 'Author' };
    this.store.findQuery('nested-question', q).then((nestedQuestions)=> {
      this.set('nestedQuestionsForNewAuthor', nestedQuestions);
    });
  }),

  newAuthor: computed('newAuthorFormVisible', function(){
    return this.store.createRecord('author', {
        paper: this.get('task.paper'),
        position: 0,
        nestedQuestions: this.get('nestedQuestionsForNewAuthor')
    });
  }),

  clearNewAuthorAnswers(){
    this.get('nestedQuestionsForNewAuthor').forEach( (nestedQuestion) => {
      nestedQuestion.clearAnswerForOwner(this.get('newAuthor'));
    });
  },

  shiftAuthorPositions(author, newPosition) {
    author.set('position', newPosition).save();
  },

  actions: {
    toggleAuthorForm() {
      this.clearNewAuthorAnswers();
      this.toggleProperty('newAuthorFormVisible');
    },

    changeAuthorPosition(author, newPosition) {
      this.shiftAuthorPositions(author, newPosition);
    },

    saveNewAuthor() {
      const author = this.get('newAuthor');

      // set this here, not when initially built so it doesn't show up in
      // the list of existing authors as the user fills out the form
      author.set('authorsTask', this.get('task'));

      author.save().then( (savedAuthor) => {
        author.get('nestedQuestionAnswers').toArray().forEach(function(answer){
          const value = answer.get('value');
          if(value || value === false){
            answer.set('owner', savedAuthor);
            answer.save();
          }
        });
        this.toggleProperty('newAuthorFormVisible');
      });
    },

    saveAuthor(author) {
      author.save();
    },

    removeAuthor(author) {
      author.destroyRecord();
    }
  }
});
