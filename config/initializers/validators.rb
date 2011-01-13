module ActiveModel

  module Validations
    class ObjectIdValidityValidator < EachValidator
      def validate_each(record, attribute, value)
        record.errors[attribute] << 'is not a valid BSON::ObjectId' unless value.valid_bson_object_id?
      end
    end
  end
end