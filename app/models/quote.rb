class Quote
	include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps

  validates :subtotal_amount, :shipping_amount, :tax_amount, :address, :order_items, :presence => true

	embeds_one :address, :validate => false
	embeds_many :order_items
	referenced_in :user
	referenced_in :coupon
	references_one :order, :validate => false

	index :system
	index :created_at
	index :active
	index "address.last_name"
	index "order_items.item_num"
	index :updated_at

  field :active, :type => Boolean, :default => true
  field :quote_number
	field :system
	field :locale
	field :ip_address
	field :subtotal_amount, :type => Float
	field :shipping_amount, :type => Float
	field :handling_amount, :type => Float
	field :total_discount, :type => Float
	field :tax_amount, :type => Float
	field :vat_exempt, :type => Boolean, :default => false
	field :vat_percentage, :type => Float
	field :tax_exempt, :type => Boolean, :default => false
	field :tax_exempt_number
	field :tax_transaction
	field :tax_calculated_at, :type => DateTime
	field :tax_commited, :type => Boolean, :default => false
	field :to_review, :type => Boolean, :default => false

	field :shipping_priority, :default => "Normal"
	field :shipping_service
	field :shipping_overridden, :type => Boolean, :default => false
	field :comments
	field :internal_comments
	field :customer_rep
	field :customer_rep_id, :type => BSON::ObjectId
	field :order_reference
	field :coupon_code
	field :old_id_er, :type => Integer
	field :old_id_eeus, :type => Integer

  field :expires_at, :type => DateTime

	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :system => sys }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex
	end
	
	scope :active, lambda { where(:active => true, :expires_at.gt => Time.zone.now) }

	before_create :set_system
	before_create :set_expires_at

  def gross_subtotal_amount
	  self.vat_exempt ? subtotal_amount : subtotal_amount + tax_amount
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
	  self.vat_exempt ? 0.0 : (self.shipping_amount * (self.vat_percentage/100.0)).round(2)
	end
	
	def can_be_converted?
	  self.expires_at > Time.zone.now && products.count == order_items.count && (is_ee_us? || is_er? && order_items.all? {|e| e.product.available? && e.product.quantity >= e.quantity})
	end
	
	def products
	  Product.available.any_in(:item_num => order_items.map {|e| e.item_num}).cache
	end
	
	def destroy
    update_attribute :active, false
  end

private

	def set_system
		self.system ||= current_system
	end
	
	def set_expires_at
	  self.expires_at = is_ee? ? 90.days.from_now : 6.months.from_now
	end
end