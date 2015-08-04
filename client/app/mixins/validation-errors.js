import Ember from 'ember';
import Utils from 'tahi/services/utils';

/**
  ## How to Use

  In your template:

  ```
  {{error-message message=validationErrors.email}}
  <label>
    Email <input>
  </label>
  ```

  In your component:

  ```
  import Ember from 'ember';
  import ValidationErrorsMixin from 'tahi/mixins/validation-errors';

  export default Ember.Component.extend(ValidationErrorsMixin, {
    actions: {
      save() {
        this.get('model').save().then(() => {
          this.clearAllValidationErrors();
        }, (response) => {
          this.displayValidationErrorsFromResponse(response);
        });
      }
    }
  });
  ```

  ## How it Works

  The mixin adds a `validationErrors` property to your Object.
*/

export default Ember.Mixin.create({
  /**
    Create validationErrors property.

    @private
    @method _initValidationErrors
  */

  validationErrors: null,
  _initValidationErrors: (function() {
    this.set('validationErrors', {});
  }).on('init'),

  /**
    Take response from Rails, camelize keys and join arrays.

    @private
    @method _prepareResponseErrors
    @return {Object}
  */

  _prepareResponseErrors(errors, options) {
    var errorsObject = Utils.deepJoinArrays(Utils.deepCamelizeKeys(errors));

    if (options && options.includeNames) {
      for(var key in errorsObject) {
        errorsObject[key] = `${key.capitalize()} ${errors[key]}`;
      }
    }
    return errorsObject;
  },

  /**
    Get pluralized name of model.

    @private
    @method _typeFromModel
    @return {String}
  */

  _typeFromModel(model) {
    return model.get('constructor.modelName').camelize().pluralize();
  },

  /**
    TODO: You! Be a good citizen and document this method!

    @method createModelProxyObjectWithErrors
    @param {Array} models Array of (most likely) DS.Models
    @return {Array} array of hashes with `model` and `error` keys
  */

  createModelProxyObjectWithErrors(models) {
    return models.map((model) => {
      return Ember.Object.create({
        model: model,
        errors: this.validationErrorsForModel(model)
      });
    });
  },

  /**
    TODO: You! Be a good citizen and document this method!

    @method validationErrorsForType
    @param {DS.Model}
    @return {Array}
  */

  validationErrorsForType(model) {
    return this.get('validationErrors')[this._typeFromModel(model)] || [];
  },

  /**
    TODO: You! Be a good citizen and document this method!

    @method validationErrorsForModel
    @param {DS.Model}
    @return {Hash}
  */

  validationErrorsForModel(model) {
    return this.validationErrorsForType(model)[model.get('id')];
  },

  /**
    TODO: You! Be a good citizen and document this method!

    @method displayValidationError
    @param {String} key
    @param {String|Array} value
  */

  displayValidationError(key, value) {
    this.set('validationErrors.' + key, (Ember.isArray(value) ? value.join(', ') : value));
  },

  /**
    Remove all validation errors. Should be called on a successful save, for example.
    ```
    this.get('model').save().then(() => {
      // success
    }, (response) => {
      this.displayValidationErrorsFromResponse(response);
    });
    ```

    Response expected to be in Rails format:
    ```
    { errors: { someProperty: ["is invalid", "another error"] } }
    ```

    @method displayValidationErrorsFromResponse
    @param {Object} response Hash from Ember Data `save` failure. Expected to be in format Rails sends.
  */

  displayValidationErrorsFromResponse(response, options) {
    this.set('validationErrors', this._prepareResponseErrors(response.errors, options));
  },

  /**
    Remove all validation errors. Should be called on a successful save, for example.
    ```
    this.get('model').save().then(() => {
      this.clearAllValidationErrors();
    });
    ```

    @method clearAllValidationErrors
  */

  clearAllValidationErrors() {
    this.set('validationErrors', {});
  },

  /**
    Remove all validation errors for a specific model.

    @method clearAllValidationErrorsForModel
    @param {DS.Model}
  */

  clearAllValidationErrorsForModel(model) {
    delete this.validationErrorsForType(model)[model.get('id')];
  }
});
