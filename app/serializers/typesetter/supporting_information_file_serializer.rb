module Typesetter
  # Serializes a supporting information file for the typesetter.
  # Expects a supporting information file as its object to serialize.
  class SupportingInformationFileSerializer < ActiveModel::Serializer
    attributes :title, :caption, :file_name

    private

    def file_name
      File.basename object.attachment.path
    end
  end
end