module OldData
  class UspsZone < ActiveRecord::Base
    validates_presence_of :zip_prefix, :zone
    validates_numericality_of :zip_prefix, :zone
  end
end