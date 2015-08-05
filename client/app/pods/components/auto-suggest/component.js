import Ember from 'ember';
import RESTless from 'tahi/services/rest-less';

/* Template:
 * {{#auto-suggest endpoint="/api/users"
 *                 queryParameter="email"
 *                 placeholder="Search for user by email address"
 *                 parseResponseFunction=parseUserSearch
 *                 itemDisplayTextFunction=something
 *                 itemSelected="userSelected"
 *                 unknownItemSelected="newUserSelected"
 *                 as |user|}}
 *   {{user.fullName}} - {{user.email}}
 * {{/auto-suggest}}
 *
 * Controller: {
 *   parseUserResponse(response) {
 *     return response.users;
 *   },
 *
 *   something(user) {
 *     return user.email;
 *   }
 * }
*/

export default Ember.Component.extend({
  classNames: ['form-control', 'auto-suggest-border'],

  // -- attrs:

  /**
   *  Endpoint for HTTP request
   *
   *  @property endpoint
   *  @type String
   *  @default null
   *  @required
   **/
  endpoint: null,

  /**
   *  Query tacked on end of endpoint
   *  /api/users?email=
   *
   *  @property queryParameter
   *  @type String
   *  @default null
   *  @required
   **/
  queryParameter: null,

  /**
   *  Function called to manipulate data before displaying in component
   *  function(response) { return response.users.sort.map.filter.etc.etc.etc; }
   *
   *  @property queryParameter
   *  @type String
   *  @default null
   *  @required
   *  @param {Object} http request response
   **/
  parseResponseFunction: null,

  /**
   *  When an item is chosen from the list, this function can be used
   *  to display text in the input.
   *
   *  @property itemDisplayTextFunction
   *  @type Function
   *  @default null
   *  @param {Object|Array} A single item from your datasource
   *  @return String
   **/
  itemDisplayTextFunction: null,

  /**
   *  Placeholder text for input
   *
   *  @property placeholder
   *  @type String
   *  @default null
   **/
  placeholder: null,
  // itemSelected (action)
  // unknownItemSelected (action)

  // -- props:
  debounce: 300,
  highlightedItem: null,
  resultText: null,
  searchAllowed: true,
  searchResults: null,
  selectedItem: null,
  searching: 0,

  search() {
    if (!this.get('resultText')) { return; }

    this.incrementProperty('searching');
    let url = this.get('endpoint');
    let data = {};
    data[this.get('queryParameter')] = this.get('resultText');

    RESTless.get(url, data).then((response) => {
      let results = this.get('parseResponseFunction')(response);
      this.set('searchResults',  results);
      this.decrementProperty('searching');
    },
    () => {
      this.decrementProperty('searching');
    });
  },

  _resultTextChanged: Ember.observer('resultText', function() {
    if(this.get('searchAllowed')) {
      Ember.run.debounce(this, this.search, this.get('debounce'));
    }

    this.set('searchAllowed', true);
  }),

  _setupKeybindings: Ember.on('didInsertElement', function() {
    $(document).on('keyup.autosuggest', (event) => {
      if (event.which === 27) {
        this.set('highlightedItem', null);
      }

      if(event.which === 13 || event.which === 27) {
        let highlightedItem = this.get('highlightedItem');

        if(highlightedItem) {
          this.selectItem(highlightedItem);
        } else {
          this.sendAction('unknownItemSelected', this.get('resultText'));
        }
        this.set('highlightedItem', null);
        this.set('searchResults', null);
      }
    });
  }),

  selectItem(item) {
    this.set('searchAllowed', false);
    this.set('selectedItem', item);
    this.sendAction('itemSelected', item);

    if(this.itemDisplayTextFunction) {
      let textForInput = this.itemDisplayTextFunction(item);
      this.set('resultText', textForInput);
    }

    this.set('searchResults', null);
  },

  actions: {
    selectItem(item) {
      this.selectItem(item);
    }
  }
});