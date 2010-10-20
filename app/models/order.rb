class Order
	include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	include ActiveModel::Validations
	include ActiveModel::Translation
	
	STATUSES = ["New", "Pending", "Open", "Processing", "In Process", "Shipped", "To Refund", "Refunded", "Cancelled"]
	
	embeds_one :payment
	embeds_one :address
	embeds_many :order_items
	referenced_in :user
	referenced_in :coupon
	
	index :status 
	index :system
	index :created_at
	index "address.last_name"
	index "order_items.item_num"
	index "order_items.product_id"
	
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
	field :tax_commited, :type => Boolean, :default => false
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
	
	field :clickid
	field :utm_source
	field :tracking
	
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :system => sys }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex
	end
	
	before_create :set_system
	
	def total_amount
		subtotal_amount + shipping_amount + handling_amount + tax_amount
	end
	
	def decrement_items!
		order_items.each do |item|
			Product.find(item.product_id).decrement_quantity(item.quantity) rescue next
		end
	end

private
	
	def set_system
		self.system ||= current_system
	end
end