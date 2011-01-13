require 'active_support/core_ext/object/blank'

class Object
  def valid_bson_object_id?
    #const_defined?(:ELLISON_SYSTEMS)
    self.is_a?(BSON::ObjectId) || BSON::ObjectId.legal?(self)
  end
end