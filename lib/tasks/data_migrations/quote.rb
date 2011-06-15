module OldData
  class Quote < ActiveRecord::Base
    validates_presence_of :quote
    validates_uniqueness_of :quote
    belongs_to :user
    belongs_to :product
    has_many :order_items
    belongs_to :sales_rep, :class_name => "User", :foreign_key => "sales_rep_id"
    named_scope :active, lambda {{ :conditions => ['active = ? AND expires_at > ?', true, Time.zone.now] } }

    def uk_tax_amount
      self.vat_exempt ? 0.0 : self.subtotal_amount * (current_vat_percentage/100.0)
    end
    
    def current_vat_percentage
      order_items.first.vat_percentage
    end
  end
end