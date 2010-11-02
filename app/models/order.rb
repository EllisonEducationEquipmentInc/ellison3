class Order
	include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	include ActiveModel::Validations
	include ActiveModel::Translation
	
	# have to be titlized
	STATUSES = ["New", "Pending", "Open", "Processing", "In Process", "Shipped", "To Refund", "Refunded", "Cancelled"]
	
	validates :status, :subtotal_amount, :shipping_amount, :tax_amount, :address, :order_items, :payment, :presence => true
	validates_inclusion_of :status, :in => STATUSES
	
	embeds_one :payment
	embeds_one :address
	embeds_many :order_items
	referenced_in :user
	referenced_in :coupon
	referenced_in :quote
	
	index :status 
	index :system
	index :created_at
	index "address.last_name"
	index "order_items.item_num"
	
	field :status, :default => "New"
	field :system
	field :locale
	field :ip_address
	field :subtotal_amount, :type => Float
	field :shipping_amount, :type => Float
	field :handling_amount, :type => Float
	field :total_discount, :type => Float
	field :tax_amount, :type => Float
	# field :vat_exempt, :type => Boolean, :default => true
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
	
	field :clickid
	field :utm_source
	field :tracking
	
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :system => sys }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex
	end
	
	before_create :set_system
	
	def total_amount
		(subtotal_amount + shipping_amount + handling_amount + tax_amount).round(2)
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