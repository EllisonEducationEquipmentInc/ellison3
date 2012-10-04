class SystemSetting
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Paranoia

  validates :key, :value, :presence => true

  field :key
  field :value

  field :created_by
  field :updated_by

  index :key, :unique => true

  class << self
    def value_at(key)
      find_by_key(key).try :value
    end

    def update(key, value)
      find_by_key(key).try :update_attributes, :value => value
    end

    def find_by_key(key)
      first(:conditions => { :key => key})
    end
  end
end
