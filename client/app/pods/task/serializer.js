import ApplicationSerializer from 'tahi/pods/application/serializer';

export default ApplicationSerializer.extend({
  serializeIntoHash(data, type, record, options) {
    return data['task'] = this.serialize(record, options);
  },
});
