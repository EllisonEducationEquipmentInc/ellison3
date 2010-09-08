class Order
	include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	include ActiveModel::Validations
	include ActiveModel::Translation
	
	embeds_one :payment
	embeds_one :address
	embeds_many :order_items
	referenced_in :user
	
	index :status 
	
	field :status, :default => "New"
	field :system
	field :locale
	field :ip_address
	field :subtotal_amount, :type => BigDecimal
	field :shipping_amount, :type => BigDecimal
	field :handling_amount, :type => BigDecimal
	field :total_discount, :type => BigDecimal
	field :tax_amount, :type => BigDecimal
	# field :vat_exempt, :type => Boolean, :default => true
	field :tax_exempt, :type => Boolean, :default => false
	field :tax_exempt_number
	field :tax_transaction
	field :tax_calculated_at, :type => DateTime
	field :tax_commited, :type => Boolean, :default => false
	field :to_review, :type => Boolean, :default => false
	field :purchase_order
	
	field :shipping_priority, :default => "Normal"
	field :shipping_overridden, :type => Boolean, :default => false
	field :tracking_number
	field :tracking_url
	field :estimated_ship_date, :type => Date
	field :comments
	field :internal_comments
	
	field :clickid
	field :utm_source
	field :tracking
	
	def total_amount
		subtotal_amount + shipping_amount + handling_amount + tax_amount
	end
end