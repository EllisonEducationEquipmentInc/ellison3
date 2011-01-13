require "mongo"

class Object
  def valid_bson_object_id?
    self.is_a?(BSON::ObjectId) || BSON::ObjectId.legal?(self)
  end
end