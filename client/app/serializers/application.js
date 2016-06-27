import Ember from 'ember';
import deNamespaceTaskType from 'tahi/lib/de-namespace-task-type';
import { ActiveModelSerializer } from 'active-model-adapter';

export default ActiveModelSerializer.extend({
  isNewSerializerAPI: true,

  // We add qualifiedType and modify type when the payload comes in.
  // Revert this on the way out.

  serialize(record, options) {
    let json = this._super(record, options);
    if (json.qualified_type) {
      json.type = json.qualified_type;
      delete json.qualified_type;
    }
    return json;
  },

  // The Task payload has a key of `type`. This is the full
  // Ruby class name. Example: "ApertaThings::ImportantTask"
  // The Ember side is only interested in the last half.
  // If `type` is simply "Task", it's ad-hoc

  normalizeTaskName(fullName) {
    const taskTypeNames = fullName.split('::');

    if (taskTypeNames.length === 1) {
      return fullName;
    }

    return deNamespaceTaskType(fullName);
  },

  // The Task payload has a key of `type`. This is the full
  // Ruby class name. Example: "ApertaThings::ImportantTask"
  // The Ember side is only interested in the last half.
  // Store the original full name in `qualified_type`
  // We snake case because our superclass expects it
  mungeTaskData(taskObj) {
    const qualifiedType  = taskObj.type;

    if (qualifiedType) {
      taskObj.qualified_type = qualifiedType;
      taskObj.type = this.normalizeTaskName(taskObj.type);
    }

    return taskObj;
  },

  mungePayloadTypes(payload) {
    const newPayload = {};
    Object.keys(payload).forEach((key) => {
      let val = payload[key];
      if (_.isArray(val)) {
        newPayload[key] = val.map(obj => this.mungeTaskData(_.clone(obj)));
      } else {
        newPayload[key] = this.mungeTaskData(_.clone(val));
      }
    });

    return newPayload;

  },

  // mutates payload
  pluralizePrimaryKeyData(singularKey, pluralKey, payload) {
    if((payload[singularKey] && payload[pluralKey])) {
      //if both keys are present, the singular key is the primary
      //record and the plural key should be sideloaded records

      payload[pluralKey].unshift(payload[singularKey]);
      delete payload[singularKey];

    } else {
      let singularPrimaryRecord = payload[singularKey];
      if (singularPrimaryRecord) {
        payload[pluralKey] = [singularPrimaryRecord];
        delete payload[singularKey];
      }
    }
  },

  //mutates payload
  removeEmptyArrays(payload) {
    //remove empty arrays
    Object.keys(payload).forEach((key) => {
      let val = payload[key];
      if (_.isArray(val) && _.isEmpty(val)) { delete payload[key]; }
    });
  },

  getPolymorphicModelName(modelName, records) {
    if (records && records[0] && records[0].type) {
      return records[0].type.dasherize();
    } else {
      return modelName;
    }
  },

  distributeRecordsByType(payload) {
    const originalKeys = Object.keys(payload);
    originalKeys.forEach((oldBucketName) => {
      if (Array.isArray(payload[oldBucketName])) {
        let records = payload[oldBucketName].slice();
        records.forEach((record) => {
          const type = record.type;
          if (type) {
            let newBucketName = type.underscore().pluralize();
            if(!payload[newBucketName]) { payload[newBucketName] = []; }

            if (newBucketName !== oldBucketName) {
              payload[newBucketName].addObject(record);
              payload[oldBucketName].removeObject(record);
            }
          }
        });
      } else {
        let record = payload[oldBucketName];
          const type = record.type;
          if (type) {
            let newBucketName = type.underscore();
            if(!payload[newBucketName]) { payload[newBucketName] = record; }

            if (newBucketName !== oldBucketName) {
              delete payload[oldBucketName];
            }
          }
      }
    });
  },

  hasMultipleTypes(records) {
    if (!Ember.isArray(records)) { return false; }

    return records.mapBy('type').uniq().length > 1
  },

  newNormalize(modelName, sourcePayload) {
    let payload = _.clone(sourcePayload);

    let singularPrimaryKey = modelName.underscore(),
    primaryKey = singularPrimaryKey.pluralize();

    // author_task: {} ===> author_tasks: [{}]
    this.pluralizePrimaryKeyData(singularPrimaryKey, primaryKey, payload);

    let primaryContent = payload[primaryKey];
    // if the primary key's content has a type, and that type is different than the modelName,
    // then THAT type should be the model name when we call super.
    let newModelName = this.getPolymorphicModelName(modelName, primaryContent);

    // the payload is 'polymorphic' if the returned type is different than the one we asked for,
    // or if the payload has multiple different types.
    let isPolymorphic = (newModelName !== modelName) || this.hasMultipleTypes(primaryContent);

    // loop through each key in the payload and move models into buckets based on their dasherized and pluralized 'type'
    // attributes if they have them
    //
    this.distributeRecordsByType(payload);

    this.removeEmptyArrays(payload);

    return {newModelName, payload, isPolymorphic}

  },

  normalizeSingleResponse(
    store, primaryModelClass, originalPayload, recordId, requestType
  ) {

      let {newModelName, payload} = this.newNormalize(primaryModelClass.modelName,
                                                 this.mungePayloadTypes(originalPayload));

      let newModelClass = store.modelFor(newModelName);
      return this._super.apply(
        this, [store, newModelClass, payload, recordId, requestType]
      );
  },

  normalizeArrayResponse(
    store, primaryModelClass, originalPayload, recordId, requestType
  ) {
      let {newModelName, payload, isPolymorphic} = this.newNormalize(primaryModelClass.modelName,
                                                                this.mungePayloadTypes(originalPayload));

      let newModelClass = store.modelFor(newModelName);
      let normalizedPayload = this._super.apply(
        this, [store, newModelClass, payload, recordId, requestType]
      );

      if (isPolymorphic) {
        if (!normalizedPayload.data) { normalizedPayload.data = []; }
        normalizedPayload.data.push(...normalizedPayload.included);
        delete normalizedPayload.included;
      }

      if (!normalizedPayload.data) { normalizedPayload.data = []; }
      return normalizedPayload;
  },

  // Make sure normalizeSaveResponse uses our normalizeSingleResponse

  normalizeSaveResponse(
    store, primaryModelClass, payload, id, requestType
  ) {
    return this.normalizeSingleResponse(...arguments);
  }
});