module OldData
  class Institution < ActiveRecord::Base
    has_many :accounts
  end
end