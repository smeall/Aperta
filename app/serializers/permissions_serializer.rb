# Serializer for Roles and Permissions
class PermissionsSerializer < ActiveModel::Serializer
  def serializable_hash
    object.to_h.merge(id: id).as_json
  end

  # This is needed to allow the permissions to side load. Works in
  # conjuction with `has_one :permissions, include: true, embed: :ids` on the
  # CurrentUserSerializer
  def id
    1
  end
end
