class Order
	include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
  
  include Mongoid::Sequence
	
	field :order_number, :type=>Integer
  sequence :order_number
  
	# have to be titlized
	STATUSES = ["New", "Pending", "Open", "Processing", "In Process", "Shipped", "To Refund", "Refunded", "Cancelled", "On Hold", "Off Hold"]
	
	validates :status, :subtotal_amount, :shipping_amount, :tax_amount, :address, :order_items, :presence => true
	validates_inclusion_of :status, :in => STATUSES
	validates_uniqueness_of :order_number, :on => :create, :message => "must be unique"
	
	embeds_one :payment
	embeds_one :address, :validate => false
	embeds_many :order_items
	referenced_in :user, :validate => false
	referenced_in :coupon, :validate => false
	referenced_in :quote, :validate => false
	
	index :status 
	index :system
	index :created_at
	index :updated_at
	index "address.last_name"
	index "address.address1"
	index "address.email"
	index "address.city"
	index "address.company"
	index "order_items.item_num"
	index :order_number
	index :subtotal_amount
	index "payment.deferred"
	index :tax_transaction
	index "payment.vpstx_id"
	index "payment.tx_auth_no"
	index "payment.purchase_order_number"
	
	field :status, :default => "New"
	field :system
	field :locale
	field :ip_address
	field :subtotal_amount, :type => Float

	field :shipping_amount, :type => Float      	            # net shipping_amount (without VAT) is stored for UK sites
	field :handling_amount, :type => Float
	field :total_discount, :type => Float
	field :tax_amount, :type => Float                         # !!! does NOT contain shipping VAT
	field :vat_exempt, :type => Boolean, :default => false
	field :vat_percentage, :type => Float
	field :tax_exempt, :type => Boolean, :default => false
	field :tax_exempt_number
	field :tax_transaction
	field :tax_calculated_at, :type => DateTime
	field :tax_committed, :type => Boolean, :default => false
	field :to_review, :type => Boolean, :default => false
	field :purchase_order
	field :shipping_priority, :default => "Normal"
	field :shipping_service
	field :carrier_description
	field :shipping_overridden, :type => Boolean, :default => false
	field :tracking_number
	field :tracking_url
	field :estimated_ship_date, :type => Date
	field :comments
	field :internal_comments
	field :customer_rep
	field :customer_rep_id, :type => BSON::ObjectId
	field :order_reference
	field :coupon_code
	field :cod_account_type
	field :cod_account
	
	field :old_quote_id, :type => Integer
	
	field :clickid
	field :utm_source
	field :tracking
	
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :system => sys }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex
	end
	
	scope :real_orders, :where => {:status.in => ["Open", "Processing", "In Process", "Shipped"]}
	scope :not_cancelled, :where => {:status.ne => 'Cancelled'}
	
	before_create :set_system
	
	class << self
	  def find_by_public_order_number(public_order_number)
	    Order.where(:system => public_order_number[/[a-z]{2,4}/i].downcase, :order_number => public_order_number[/\d+/]).first
	  end
	  
    def quanity_sold(item_num)
      map = <<EOF
        function() {
          if (this.order_items) {
            this.order_items.forEach(function(doc) {
              if (doc.item_num == '#{item_num}') emit( doc.item_num, { quantity : doc.quantity, item_total: doc.sale_price * doc.quantity} );
            })
          }
        }
EOF

      reduce = <<EOF
        function( key , values ){
          var total = 0;
          var sum = 0;
          for ( var i=0; i<values.length; i++ ){
            total += values[i].quantity;
            sum += values[i].item_total;
          }
          return { quantity : total, item_total: sum};
        };
EOF

      collection.mapreduce(map, reduce, {:out => {:inline => true}, :raw => true, :query => {"order_items.item_num" => item_num}})["results"]
    end
	end
	
	def gross_subtotal_amount
	  self.vat_exempt || self.vat_exempt.nil?  ? subtotal_amount : subtotal_amount + tax_amount
	rescue
	  subtotal_amount
	end
	
	def gross_shipping_amount
	  self.shipping_amount + shipping_vat
	end
	
	def total_amount
		(subtotal_amount + shipping_amount + handling_amount + tax_amount + shipping_vat).round(2)
	end
	
	def shipping_vat
	  self.vat_exempt ? 0.0 : (self.shipping_amount * ((self.vat_percentage || 0.0)/100.0)).round(2)
	end
	
	def decrement_items!
		order_items.each do |item|
			item.product.decrement_quantity(item.quantity) rescue next
		end
	end
	
	# if status can no longer be changed on the web
	def status_frozen?
	  !(self.status == 'New' || pending?)
	end
	
	def public_status
	  case self.status
	  when "Processing"
	    "Open"
	  when "To Refund", "Refunded"
	    "Cancelled"
	  else
	    self.status
	  end
	end
	
	def public_order_number
	  "#{order_prefix(self.system)}#{self.order_number}"
	end
	
	# true if On Hold pre-order can be paid now because all items became available
	def can_be_paid?
	  on_hold? && order_items.all? {|e| e.product.available?(self.system) && e.product.quantity(self.system) >= e.quantity}
	end
	
	def cod?
    self.shipping_service == "COD"
  end
  
  def send_shipping_confirmation
    UserMailer.delay.shipping_confirmation(self)
  end

  def delete_billing_subscription_id
    return unless self.payment && self.payment.subscriptionid.present?
    get_gateway self.system
    @gateway.delete_customer_info :subscription_id => self.payment.subscriptionid, :order_id => self.id
  end
  
	# use this format to change status:
	#   @order.in_process! 
	#   p @order.status # => "In Process"
	#
	#   to check agains a specific status:
	#   @order.in_process? # => true 
	def method_missing(key, *args)
		if s=STATUSES.detect {|e| e == key.to_s.gsub(/(\?|!)$/, '').titleize}
		  if key.to_s[-1] == "!"
		    self.status = s 
		  elsif key.to_s[-1] == "?"
		    self.status == s 
		  end
		else
		  raise NoMethodError, "undefined method `#{key}` for #{self}"
		end
	end

private
	
	def set_system
		self.system ||= current_system
	end
end