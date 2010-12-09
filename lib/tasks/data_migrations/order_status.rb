module OldData
  class OrderStatus < ActiveRecord::Base
    has_many :orders

    named_scope :active, :conditions => ['active = ?', true]

    named_scope :uk_statuses, :conditions => ['id in (?)', [3,5,6,9]]


    def self.all_statuses
      all(:conditions => ["#{flag} = ?", true])
    end

    def self.statuses
      active.all(:conditions => ["#{flag} = ?", true])
    end

    def self.cancelled
      find_by_name "Cancelled"
    end

    def self.open
      find_by_name "Open"
    end

    def self.new_status
      find_by_name "New"
    end

    def self.to_refund
      find_by_name "To Refund"
    end

    def self.refunded
      find_by_name "Refunded"
    end

    def self.shipped
      find_by_name "Shipped"
    end

    def self.in_process
      find_by_name "In Process"
    end

    def self.processing
      find_by_name "Processing"
    end


  private

    def self.flag
      case 
      when is_sizzix?
        'sizzix'
      when is_ee?
        'ee'
      when is_er?
        'er'
      end
    end
  end
  
end