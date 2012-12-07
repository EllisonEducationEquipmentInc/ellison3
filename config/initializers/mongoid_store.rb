MongoidStore::Session.class_eval do
  index [["updated_at", Mongo::DESCENDING]]
end
