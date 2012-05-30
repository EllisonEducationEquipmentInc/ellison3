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
	
	embeds_one :payment, as: :payment
	embeds_one :gift_card, class_name: "Payment", as: :payment
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
	index "order_items.campaign_name"
	index "order_items.coupon_name"
  index "order_items.gift_card"
	
	index [[:user_id, Mongo::ASCENDING], [:system, Mongo::ASCENDING], [:created_at, Mongo::DESCENDING]]
	index [[:updated_at, Mongo::DESCENDING], [:system, Mongo::DESCENDING], [:order_number, Mongo::DESCENDING], [:tax_transaction, Mongo::DESCENDING]]
  index [["order_items.campaign_name", Mongo::ASCENDING], [:system, Mongo::ASCENDING]]
  index [["address.email", Mongo::ASCENDING], ["address.company", Mongo::ASCENDING], ["address.last_name", Mongo::ASCENDING]]
	
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
	field :free_shipping_by_coupon, :type => Boolean, :default => false
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
	scope :not_cancelled, :where => {:status.nin => ['Cancelled', "To Refund", "Refunded"]}
	
	before_create :set_system
	
	class << self
	  def find_by_public_order_number(public_order_number)
	    Order.where(:system => public_order_number[/[a-z]{2,4}/i].downcase, :order_number => public_order_number[/\d+/]).first rescue nil
	  end
	  
    def quanity_sold(item_num)
      map = <<-EOF
        function() {
          if (this.order_items) {
            this.order_items.forEach(function(doc) {
              if (doc.item_num == '#{item_num}') emit( doc.item_num, { quantity : doc.quantity, item_total: doc.sale_price * doc.quantity} );
            })
          }
        }
      EOF

      reduce = <<-EOF
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
    
    def campaign_usage(campaign_name, options = {})
      start_date, end_date, system = parse_options(options)
      map = <<-EOF
        function() {
          if (this.order_items) {
            this.order_items.forEach(function(doc) {
              if (doc.campaign_name == '#{campaign_name}') emit( {item_num: doc.item_num, name: doc.name, sale_price: doc.sale_price, quoted_price: doc.quoted_price, locale: doc.locale}, {quantity: doc.quantity, item_total: doc.sale_price * doc.quantity, number_of_orders: 1, locale: doc.locale} );
            })
          }
        }
      EOF

      reduce = <<-EOF
        function( key , values ){
          var total = 0;
          var sum = 0;
          var number_of_orders = 0;
          for ( var i=0; i<values.length; i++ ){
            total += values[i].quantity;
            sum += values[i].item_total;
            number_of_orders += 1;
          }
          return {number_of_orders: number_of_orders, quantity : total, item_total: sum};
        };
      EOF

      collection.mapreduce(map, reduce, {:out => {:inline => true}, :raw => true, :query => {:status=>{"$nin"=>["Cancelled", "To Refund", "Refunded"]}, :created_at => {"$gt" => start_date.utc, "$lt" => end_date.utc}, "order_items.campaign_name" => campaign_name, "system" => current_system}})["results"]
    end
    
    def coupon_usage(coupon_code, options = {})
      map = <<-EOF
        function() {
          if (this.order_items) {
            this.order_items.forEach(function(doc) {
              if (doc.coupon_code == '#{coupon_code}') emit( {item_num: doc.item_num, name: doc.name, sale_price: doc.sale_price, quoted_price: doc.quoted_price, locale: doc.locale}, {quantity: doc.quantity, item_total: doc.sale_price * doc.quantity, number_of_orders: 1, locale: doc.locale} );
            })
          }
        }
      EOF

      reduce = <<-EOF
        function( key , values ){
          var total = 0;
          var sum = 0;
          var number_of_orders = 0;
          for ( var i=0; i<values.length; i++ ){
            total += values[i].quantity;
            sum += values[i].item_total;
            number_of_orders += 1;
          }
          return {number_of_orders: number_of_orders, quantity : total, item_total: sum};
        };
      EOF

      collection.mapreduce(map, reduce, {:out => {:inline => true}, :raw => true, :query => {:status=>{"$nin" => ["Cancelled", "To Refund", "Refunded"]}, "order_items.coupon_code" => coupon_code, "system" => current_system}})["results"]
    end
    
    def shipping_coupon_usage(coupon_code)
      map = <<-EOF
        function() {
          emit(this.locale, {subtotal_amount: this.subtotal_amount, shipping_amount: this.shipping_amount, number_of_orders: 1, line_items: this.order_items.length} );
        }
      EOF

      reduce = <<-EOF
        function( key , values ){
          var total_shipping = 0;
          var sum = 0;
          var number_of_orders = 0;
          var total_line_items = 0;
          for ( var i=0; i<values.length; i++ ){
            total_line_items += values[i].line_items
            total_shipping += values[i].shipping_amount;
            sum += values[i].subtotal_amount;
            number_of_orders += 1;
          }
          return {number_of_orders: number_of_orders, total_subtotal_amount: sum, total_shipping: total_shipping, total_line_items: total_line_items};
        };
      EOF

      collection.mapreduce(map, reduce, {:out => {:inline => true}, :raw => true, :query => {:status=>{"$nin"=>["Cancelled", "To Refund", "Refunded"]}, "coupon_code" => coupon_code, "system" => current_system}})["results"]
    end
    
    def summary(options = {})
      start_date, end_date, system = parse_options(options)
      collection.group :key => :locale, :cond => {:created_at => {"$gt" => start_date.utc, "$lt" => end_date.utc}, :system => system}, :reduce => "function(obj, out){out.subtotal += obj.subtotal_amount; out.shipping_amount += obj.shipping_amount; out.tax_amount += obj.tax_amount; out.total_amount += (obj.subtotal_amount + obj.shipping_amount + obj.tax_amount + obj.handling_amount); out.handling_amount += obj.handling_amount; out.total_discount += obj.total_discount ? obj.total_discount : 0 ; out.count++}", :initial => {:total_amount => 0, :subtotal => 0, :shipping_amount => 0, :tax_amount => 0, :handling_amount => 0, :total_discount => 0, :count => 0}
    end
    
    def status_summary(options = {})
      start_date, end_date, system = parse_options(options)
      collection.group :key => :status, :cond => {:created_at => {"$gt" => start_date.utc, "$lt" => end_date.utc}, :system => system}, :reduce => "function(obj, out){out.count++;}", :initial => {:count => 0}
    end
    
    def product_performance(tag, options = {})
      start_date, end_date, system = parse_options(options)
      map = <<-EOF.strip_heredoc
        function() {
          if (this.order_items) {
            this.order_items.forEach(function(doc) {
              if (doc.product_id && #{tag.product_ids.map(&:to_s)}.indexOf(doc.product_id.toString()) >= 0) emit( {item_num: doc.item_num, name: doc.name, sale_price: doc.sale_price, quoted_price: doc.quoted_price, locale: doc.locale, outlet: doc.outlet}, {quantity: doc.quantity, item_total: doc.sale_price * doc.quantity, number_of_orders: 1, locale: doc.locale} );
            })
          }
        }
      EOF

      reduce = <<-EOF.strip_heredoc
        function( key , values ){
          var total = 0;
          var sum = 0;
          var number_of_orders = 0;
          for ( var i=0; i<values.length; i++ ){
            total += values[i].quantity;
            sum += values[i].item_total;
            number_of_orders += 1;
          }
          return {number_of_orders: number_of_orders, quantity : total, item_total: sum};
        };
      EOF
      collection.mapreduce(map, reduce, {:out => {:inline => true}, :raw => true, :query => {:status=>{"$nin"=>["Cancelled", "To Refund", "Refunded"]}, :created_at => {"$gt" => start_date.utc, "$lt" => end_date.utc}, "order_items.product_id" => {"$in" => tag.product_ids}, "system" => current_system}})["results"]
    end
    
  private
  
    def parse_options(options)
      start_date = options[:start_date] || Time.zone.now.beginning_of_day
      end_date = options[:end_date] || Time.zone.now.end_of_day
      system = options[:system] || current_system
      [start_date, end_date, system]
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
	
	def uk_may_change?
	  is_uk? &&  (self.system == "szuk" || self.system == "eeuk") && ["Open", "Processing", "In Process", "To Refund"].include?(self.status)
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
  
  def get_customer_rep
    Admin.find(self.customer_rep_id) if self.customer_rep_id
  rescue
    nil
  end

  def gift_card?
    order_items.any? &:gift_card
  end

  def balance_due
    if gift_card.present? && gift_card.paid_amount.present?
      total_amount - gift_card.paid_amount
    else
      total_amount
    end
  end

  def billing_address
    if payment.present?
      payment
    elsif gift_card.present?
      gift_card
    end
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
