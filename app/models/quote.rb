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
  field :name
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
	field :cod_account_type
	field :cod_account
	
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
	
	field :created_by
	field :updated_by
	
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :system => sys }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex
	end
	
	scope :active, lambda { where(:active => true, :expires_at.gt => Time.zone.now) }

	before_create :set_system
	before_create :set_expires_at
	
	class << self
    # pre-order report:
    def pre_orders_report(sys = current_system)
      map = <<EOF
        function() {
          if (this.order_items) {
            this.order_items.forEach(function(doc) {
              emit( doc.item_num, { quantity : doc.quantity, item_total: doc.sale_price * doc.quantity} );
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

      collection.mapreduce(map, reduce, {:out => {:inline => true}, :raw => true, :query => {:system => sys, :active => true, :expires_at => {"$gt" => Time.now.utc}}})["results"]
    end
	end

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
	  active_quote? && products.count == order_items.count && order_items.all? {|e| e.product.can_be_purchased?(self.system, e.quantity)}
	end
	
	def active_quote?
	  self.active && self.expires_at > Time.zone.now
	end
	
	def products
	  Product.available.any_in(:item_num => order_items.map {|e| e.item_num}).cache
	end
	
	def destroy
    update_attribute :active, false
  end
  
  def cod?
    self.shipping_service == "COD"
  end

private

	def set_system
		self.system ||= current_system
	end
	
	def set_expires_at
	  self.expires_at = is_ee? ? 90.days.from_now : 6.months.from_now
	end
end