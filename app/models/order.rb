class Order
	include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	include ActiveModel::Validations
	include ActiveModel::Translation
  
  include Mongoid::Sequence
	
	field :order_number, :type=>Integer
  sequence :order_number
  
	# have to be titlized
	STATUSES = ["New", "Pending", "Open", "Processing", "In Process", "Shipped", "To Refund", "Refunded", "Cancelled"]
	
	validates :status, :subtotal_amount, :shipping_amount, :tax_amount, :address, :order_items, :payment, :presence => true
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
	index "order_items.item_num"
	index :order_number
	index :subtotal_amount
	
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
	
	field :old_quote_id, :type => Integer
	
	field :clickid
	field :utm_source
	field :tracking
	
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :system => sys }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex
	end
	
	scope :real_orders, :where => {:status.in => ["Open", "Processing", "In Process", "Shipped"]}
	
	before_create :set_system
	
	class << self
	  def find_by_public_order_number(public_order_number)
	    Order.where(:system => public_order_number[/[a-z]{2,4}/i].downcase, :order_number => public_order_number[/\d+/]).first
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
	  !(new? || pending?)
	end
	
	def public_status
	  case self.status
	  when "Processing"
	    "Open"
	  when "To Refund" || "Refunded"
	    "Cancelled"
	  else
	    self.status
	  end
	end
	
	def public_order_number
	  "#{order_prefix(self.system)}#{self.order_number}"
	end
	
	# to this format to change status:
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