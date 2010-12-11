require File.expand_path(File.dirname(__FILE__) + '/order_status')
module OldData
  class Order < ActiveRecord::Base
    has_many :order_items
    belongs_to :user
    belongs_to :payment
    #belongs_to :quote
    belongs_to :sales_rep, :class_name => "User", :foreign_key => "sales_rep_id"
    belongs_to :order_status

    # include OrderStatusUpdater


    # UK notes: 
    # shipping_amount is NET (without VAT)
    # tax_amount contains shipping VAT

    # named_scope :open, :conditions => ['order_status_id = ?', OrderStatus.open.id]
    # named_scope :shipped, :conditions => ['order_status_id = ?', OrderStatus.shipped.id]
    # named_scope :tax_not_committed, :conditions => ['tax_committed = ? AND tax_transaction_id IS NOT NULL', false]

    attr_accessor :tax_exempt_certificate

    def cancel!
      update_attribute(:order_status, OrderStatus.cancelled)
    end

    def refund!
      update_attribute(:order_status, OrderStatus.refunded)
    end

    def open!
      write_attribute(:order_status, OrderStatus.open.name) if is_uk?
      update_attribute(:order_status, OrderStatus.open)
      #GlobalOrder.push(self) if is_er?
      #RemoteGlobalOrder.push(self) if is_sizzix_us? || is_ee_us?
    end

    def update_status(order_status_id)
      if OrderStatus.open.id == order_status_id.to_i
        open!
      else
        write_attribute(:order_status, OrderStatus.find(order_status_id).try(:name)) if is_uk?
        update_attribute(:order_status_id, order_status_id)
      end
    end

    def to_refund?
      order_status == OrderStatus.to_refund
    end

    def po?
      !payment.purchase_order.blank? rescue false
    end
    
    def status_name
      order_status.try :name
    end
    
    def uk_tax_amount
      self.vat_exempt ? 0.0 : self.subtotal_amount * (current_vat_percentage/100.0)
    end
    
    def uk_shipping_tax
      
    end
    
    def current_vat_percentage
      order_items.first.vat_percentage
    end

  end
  
end