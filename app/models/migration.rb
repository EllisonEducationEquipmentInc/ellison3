class Migration
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps

  validates_presence_of :name
  validates_uniqueness_of :name

  field :name

  index :name
end
