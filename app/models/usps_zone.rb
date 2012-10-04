class UspsZone
  include EllisonSystem
  include Mongoid::Document

  field :zip_prefix
  field :zone, :type => Integer

  index :zip_prefix

  validates_presence_of :zip_prefix, :zone
  validates_numericality_of :zip_prefix, :zone

  class << self

    def get_zone(zip_prefix)
      where(:zip_prefix => zip_prefix).cache.first
    end
  end
end
