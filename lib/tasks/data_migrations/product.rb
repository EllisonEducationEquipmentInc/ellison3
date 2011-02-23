# encoding: utf-8
module OldData
  class Product < ActiveRecord::Base
    extend ActiveSupport::Memoizable

    # need access to the logged in user in the model level in order to determine current_user.catalog.discount
    cattr_accessor :current_user
    cattr_accessor :custom_prices
    cattr_accessor :highest_item_in_cart
  	attr_accessor :to_reindex

    named_scope :active, :conditions => ["products.active = ?", 1]
    named_scope :productlimit, :conditions => {:limit => 4}
    named_scope :deleted, :conditions => ["deleted = ?", true]
  	named_scope :not_deleted, :conditions => ["deleted = ?", false]
    named_scope :available, lambda {{:conditions => ["products.active = ? AND products.deleted = ? AND products.start_date <= ? AND  products.end_date >= ? AND products.availability IN (1,3) AND products.clearance != ?", true, false, Time.zone.now, Time.zone.now, true]}}
    named_scope :all_available, lambda {{:conditions => ["products.active = ? AND products.deleted = ? AND products.start_date <= ? AND  products.end_date >= ? AND products.availability = ?", true, false, Time.zone.now, Time.zone.now, 1]}}
    named_scope :brand_available, lambda {{:conditions => ["products.active = ? AND products.deleted = ? AND products.start_date <= ? AND  products.end_date >= ? AND products.availability != ?  AND products.clearance != ?", true, false, Time.zone.now, Time.zone.now, 0, true]}}
    named_scope :report_available, lambda {|c| {:conditions => ["active = ? AND deleted = ? AND start_date <= ? AND  end_date >= ? AND availability IN (1,3)", true, false, c, c]}}
    named_scope :report_stock, lambda {|c| {:conditions => ["active = ? AND deleted = ? AND start_date <= ? AND  end_date >= ? AND availability IN (1,3)", true, false, c, c]}}
    named_scope :id_only, :select => "id"  
  	named_scope :clearance, :conditions => ['clearance = ?', true]
  	named_scope :not_outlet, :conditions => ['clearance = ?', false]
  	named_scope :current, :conditions => ['pre_order = ?', false]
  	named_scope :pre_order, :conditions => ['pre_order = ?', true]


    named_scope :brand_items, lambda {|c| {:conditions => ["item_num in ( ? )", c]} }
    named_scope :in_catalog, lambda { |catalog_products| {:include => 'catalogs', :conditions => ['products.id IN (?)', catalog_products] } }

    named_scope :configs, lambda { |param| {:include => 'product_config', :conditions => ['products.item_code = ?', param], :select => "products.id, products.item_num, products.item_code, products.product_config_id, product_configs.name, product_configs.id, product_configs.additional_name", :order => "case when product_configs.display_order IS NULL then 9999 else product_configs.display_order end,  product_configs.additional_name" } }
    named_scope :config_count, lambda { |param| { :conditions => ['products.item_code = ?', param] } }

    named_scope :new_products, lambda { { :conditions => ['life_cycle = ? AND life_cycle_ends > ?', 'New', Time.zone.now ] } }
    named_scope :default_config, :conditions => ['default_config = ?', true]
    named_scope :related_available, lambda {{:conditions => ["products.active = ? AND products.deleted = ? AND products.start_date <= ? AND  products.end_date >= ? AND products.availability = ?", true, false, Time.zone.now, Time.zone.now, 1]}}
    named_scope :minimum_fields, :select => "products.id, products.name, products.availability, products.quantity, products.start_date, products.end_date, products.active, products.deleted,  products.item_num, products.item_code, products.product_config_id, products.medium_image"
    named_scope :default_config_first, :order => 'default_config DESC'


    #after_save :flush_cache
    #after_save :empty_cache
    after_create :clear_all_products
  	before_save :set_outlet_since
  	after_save {|record| record.index! rescue '' if record.to_reindex == "1"}

    if is_us?
      STORE_VALUES = {  '<a href="/contact">Call now to place your order</a>' => "cntpyo", '<a href="/stores">Check Your Local Craft Store</a>' => "cylcs",  '<a href="/stores">Available at your Local Retailer</a>' => "retailer", '<a href="http://www.stampinup.com/ECWeb/CategoryPage.aspx?categoryID=180" target="_blank">Stampin\' Up! Exclusive Product</a>' => 'stampin'}
      ADMIN_STORE_VALUES = { "Call now to place your order" => "cntpyo", "Check Your Local Craft Store" => "cylcs", "Available at your Local Retailer" => 'retailer', "Stampin\' Up! Exclusive Product" => 'stampin', "Custom" => "custom"}
    else
      STORE_VALUES = {  '<a href="/contact">Call now to place your order</a>' => "cntpyo", '<a href="/stores">Check Your Local Craft Store</a>' => "cylcs",  '<a href="/stores">Available at your Local Retailer</a>' => "retailer",  '<a href="/stores">Coming soon to your local Retailer</a>' => 'soon'}
      ADMIN_STORE_VALUES = { "Call now to place your order" => "cntpyo", "Check Your Local Craft Store" => "cylcs", "Available at your Local Retailer" => 'retailer', "Coming soon to your local Retailer" => 'soon', "Custom" => "custom"} 
    end
    
    def store_values
      if is_us?
        {  '<a href="/contact">Call now to place your order</a>' => "cntpyo", '<a href="/stores">Check Your Local Craft Store</a>' => "cylcs",  '<a href="/stores">Available at your Local Retailer</a>' => "retailer", '<a href="http://www.stampinup.com/ECWeb/CategoryPage.aspx?categoryID=180" target="_blank">Stampin\' Up! Exclusive Product</a>' => 'stampin'}
      else
        {  '<a href="/contact">Call now to place your order</a>' => "cntpyo", '<a href="/stores">Check Your Local Craft Store</a>' => "cylcs",  '<a href="/stores">Available at your Local Retailer</a>' => "retailer",  '<a href="/stores">Coming soon to your local Retailer</a>' => 'soon'}
      end
    end

    has_many :products_tabs, :order => "display_order, id", :dependent => :destroy
    has_many :tabs, :through => :products_tabs, :order => "products_tabs.display_order, products_tabs.id", :uniq => true

    belongs_to :product_config
    belongs_to :designer, :conditions => "designers.active = 1 AND designers.deleted = 0"
    belongs_to :type
    belongs_to :model
    has_many :orders_products 
    has_many :cart_items 
    has_many :order_items
    has_and_belongs_to_many :sz_order, :foreign_key => 'order_id'
    has_and_belongs_to_many :catalogs
    has_many :quotes
    belongs_to :discount_category

    # =====validations =====
    validates_presence_of  :name 
    validates_presence_of  :item_num,:axapta_id 
    validates_format_of :image, :with => /^.+\.(jpg|JPG|jpeg|png|gif)$/
    validates_format_of :small_image, :with => /^.+\.(jpg|JPG|jpeg|png|gif)$/
    validates_format_of :medium_image, :with => /^.+\.(jpg|JPG|jpeg|png|gif)$/
    validates_uniqueness_of :item_num 
    validates_presence_of :item_code, :if => Proc.new {|p| p.is_ee?}
    validates_presence_of :discount_category_id, :if => Proc.new(&:is_er?)

    #validates_presence_of :upc

    #validates_presence_of :model_id, :type_id
    validates_presence_of  :availability #, :msrp

    validates_numericality_of  :availability, :only_integer => true
    #validates_numericality_of :regular_price, :msrp
    validates_numericality_of :quantity
  	validates_presence_of :outlet_price, :on => :update, :if => Proc.new(&:clearance)
  # ==== relationships ====
    has_many :products_whishlists
    has_many :wishlists, :through => :products_whishlists
    has_many :orders
    has_many :prices
    has_and_belongs_to_many       :categories, :validate => false
    has_and_belongs_to_many       :tags, :validate => false
    has_many                      :campaigns_categories_products
    # has_and_belongs_to_many       :campaigns #, :order => 'name'
    has_many :campaigns_products, :dependent => :destroy
    has_many :campaigns, :through => :campaigns_products, :order => 'name'

    has_and_belongs_to_many       :ideas

    has_and_belongs_to_many :cross_sell_products,
                            :join_table => 'cross_sells',
                            :foreign_key => 'product_id',
                            :association_foreign_key => 'cross_sell_product_id',
                            :class_name => 'Product',
                            :order => 'cs_position',
                            :validate => false

    has_and_belongs_to_many :cross_seller_products,
                            :join_table => 'cross_sells',
                            :foreign_key => 'cross_sell_product_id',
                            :association_foreign_key => 'product_id',
                            :class_name => 'Product'

    has_and_belongs_to_many :coupons
    has_and_belongs_to_many :product_groups
  	has_and_belongs_to_many :machines, :uniq => true

  	has_and_belongs_to_many :polymorphic_tags, :uniq => true

  	# create polymorphic_tags association methods by name with "poly_" prefix: @product.poly_categories #=> Array of associated "category" polymorphic_tags
  	PolymorphicTag::TYPES.values.each do |e|
  		class_eval "def poly_#{e.to_s.pluralize}\n  polymorphic_tags.available.send(\"#{e.to_s.pluralize}\") \n end"
  	end

  	class << self
  		# sunspot-rails overwrites ActiveRecord::Base.benchmark method, but we still need it
  		alias :ar_benchmark :benchmark

  		def retailer_discount(discount_category_id)
        if is_er? && current_user && current_user != :false && !current_user.discount_level.blank?
          product_discount = DiscountMatrix.get_matrix(discount_category_id, current_user.discount_level.id)
          product_discount ? product_discount/100.0 : 0.0 #current_user.discount_level.discount/100.0 
        else
          BigDecimal.new "0.0"
        end
      end
  	end
  	
  	def new_life_cycle
  	  return 'pre-release' if self.pre_order
  	  return 'discontinued' if self.life_cycle == 'Clearance-Discontinued'
  	  if self.availability == 0
  	    'unavailable'
  	  elsif self.availability == 2
  	    'discontinued'
  	  elsif self.availability == 1 || self.availability == 3
  	    'available'
  	  end
  	end
  	
  	def new_active_status
  	  return false if self.availability == 0
  	  self.active
  	end
  	
  	def new_orderable
  	  self.active && self.availability == 1
  	end

  	def localize_price(price_method = :msrp, temp_locale = 'en-UK')
  		# does NOT caclulate localized prices if is_us? (it only works if app was booted with ENV['local'] = "en-UK" or ENV['local'] = "en-EU") so indexing won't take too long on US sites
  		return send(price_method) if is_us?
  		@current_locale = I18n.locale
  		I18n.locale = temp_locale
  		unmemoize_all
  		localized_price = send price_method
  		I18n.locale = @current_locale
  		unmemoize_all
  		localized_price
  	end

  	def self.reindex_all
  		index
  	end

    # decrement quantity without updating created_at attribute (product cache won't expire every time quantity gets decremented)
    def decrement_quantity(qty)
      reload
      if quantity - qty <= QUANTITY_THRESHOLD
        update_attribute(:quantity, quantity - qty)
  			index! rescue ''
      else
        self.class.update_counters id, :quantity => -(qty.to_i)
        reload
      end
    end

    def set_quantity(qty)
      reload
      if (quantity <= QUANTITY_THRESHOLD && qty <= QUANTITY_THRESHOLD) || (quantity > QUANTITY_THRESHOLD && qty > QUANTITY_THRESHOLD)
        self.class.update_all("quantity = #{qty.to_i}", "id = #{id}")
        reload
      else
        update_attribute(:quantity, qty)
  			index! rescue ''
      end
    end

    def config_name
      return nil unless is_ee?
      #self.class.benchmark("config_name #{id}") do
        self.class.config_count(item_code).count < 2 ? nil : (product_config.config_group rescue '')
      #end
    end

  	def available_in
  		!config_name || self.class.configs(item_code).available.length < 2 ? nil : (config_name.pluralize rescue "configurations")
  	end

    def config
      product_config.name rescue nil
    end

  	def additional_config_name
  		product_config.try :additional_name
  	end

  	def saving
  		s = ((msrp - price)/msrp * 100).round rescue 0
  		s.respond_to?(:nan?) && s.nan? ? 0 : s
  	end

    def item
      #is_ee_us? ? item_code : item_num
      item_num
    end

    def myname
      "[" + "#{item_num}" + "]" + " #{name}"
    end

  	def effective_life_cycle
  		life_cycle if life_cycle_ends.blank? || Time.zone.now < life_cycle_ends
  	end

  	# converts to outlet product, and sets the outlet_price (in the following precedence order): 'final_price' which is sent as an attribute, exisiting 'outlet_price', actual current 'price'
  	def outlet!(final_price = nil)
  		self.clearance = true
  		op = final_price || outlet_price
  		self.outlet_price = op || price
  		self.regular_price = msrp
  		save(false)
  	end

    def custom_price
      begin
        @custom_price ||= custom_prices[id]
      rescue
      end
      @custom_price
    end

    def custom_price=(p)
      @custom_price = p.to_f.round_to(2)
    end

    # 'price' is a virtual attribute 
    def price 
      #self.class.benchmark("price #{id}") do
        pr = sale_price || regular_price
  		  @price = custom_price ? custom_price : pr 
  		#end
    end 

  	def outlet?
  		clearance
  	end

  	def outlet_price
  		return nil if new_record? || !clearance
  		begin
        prices.first(:conditions => ["locale = ?", I18n.locale[-2,2]]).outlet_price 
  		rescue Exception => e
  		  prices.first(:conditions => ["locale = ?", 'US']).try(:outlet_price)
      end
  	end

  	def outlet_price=(p)
      prices.find_or_create_by_locale(:locale => locale).update_attribute(:outlet_price, p) #if clearance
  		outlet_price(true)
    end

    def sale_price(date = Time.zone.now)
  		if clearance && outlet_price
  			outlet_price
      else
  			sale_discount(date) ? base_price - BigDecimal.new(sale_discount(date).to_s).to_f.round_to(2) : nil
  		end
    end

    def sale_discount(date = Time.zone.now)
      sd = abs_sale_discount(date)
      sd.nil? || (sd && base_price >= sd) ? sd : base_price
    end

    def abs_sale_discount(date = Time.zone.now)
      Coupon.sale_discount(self, date)
    end

    def promo_text(date = Time.zone.now)
      Coupon.promo_text(self, date)
    end

    def campaign_title(date = Time.zone.now)
      Coupon.campaign_title(self, date)
    end

    def campaign_name(date = Time.zone.now)
      Coupon.campaign_name(self, date)
    end

    def campaign_id(date = Time.zone.now)
      Coupon.campaign_id(self, date)
    end

    def catalog_discount
      if is_er? && current_user && current_user != :false && !current_user.catalogs.available.blank?
  		  cd = [0]
  		  current_user.catalogs.available.each do |c|
  		    cd << c.discount if c.products.to_a.include? self
  		  end
  		  cd = cd.sort!.last
  		  @catalog_discount = (cd.to_f/100.to_f)
      else
        @catalog_discount = BigDecimal.new "0.0"
      end
    end

    def retailer_discount
      self.class.retailer_discount(discount_category_id)
    end

    def price=(p) 
  	  @price = p.to_f.round_to(2)
    end

    # price setter methods
    def msrp=(p)
      prices.find_or_create_by_locale(:locale => locale).update_attribute(:msrp, p)
      flush_cache :msrp
    end

    def msrp_gbp=(p)
      prices.find_or_create_by_locale(:locale => "UK").update_attribute(:msrp, p)
      flush_cache :msrp
    end

    def msrp_eur=(p)
      prices.find_or_create_by_locale(:locale => "EU").update_attribute(:msrp, p)
      flush_cache :msrp
    end

    def regular_price=(p)
      prices.find_or_create_by_locale(:locale => locale).update_attribute(:regular_price, p)
      flush_cache :regular_price
    end

    def regular_price_gbp=(p)
      prices.find_or_create_by_locale(:locale => "UK").update_attribute(:regular_price, p)
      flush_cache :regular_price
    end

    def regular_price_eur=(p)
      prices.find_or_create_by_locale(:locale => "EU").update_attribute(:regular_price, p)
      flush_cache :regular_price
    end

    def locale
      I18n.locale[-2,2] rescue 'US'
    end

    # only for ER. For all other systems, it's the same as regular_price
    def wholesale_price
      return msrp if clearance
      prices.first(:conditions => ["locale = ?", I18n.locale[-2,2]]).regular_price
  	rescue Exception => e
  	  prices.first(:conditions => ["locale = ?", 'US']).regular_price
    end

    def regular_price
      return msrp if clearance
      rp = wholesale_price
      if is_er? && rp <= msrp
        rp = rp - rp * retailer_discount
  			rp.respond_to?(:round_to) ? rp.round_to(2) : rp
      elsif rp > msrp
        msrp
      else
        rp
      end
    end

    def msrp(locale = nil)
      locale ||= I18n.locale[-2,2]
      begin
        m = prices.first(:conditions => ["locale = ?", locale]).msrp
      rescue  
  	    m = prices.first(:conditions => ["locale = ?", 'US']).msrp
      end
      m #- (m * catalog_discount)
    end

    # this is the base price the discount will be applied to
    def base_price
      is_er? ? wholesale_price : regular_price
    end

    def coupon_price(cart)
      return custom_price if custom_price
      if sale_price
        base_price - coupon_discount(cart) < sale_price ? base_price - coupon_discount(cart) : sale_price
      else
        base_price - coupon_discount(cart) < price ? base_price - coupon_discount(cart) : price
      end
    end

    def coupon_discount(cart)
      return 0.0 if custom_price
      disc = 0.0
      cart = Cart.new(:coupon => cart) if cart.kind_of?(CouponGroup) || cart.kind_of?(Coupon)
      if cart.coupon
        if cart.coupon.kind_of?(CouponGroup)
          discounts = []
          cart.coupon.coupons.each do |c|
            next if c.banner_only || c.level == 3 || (c.level == 1 && cart.gross_price < c.threshold)
            discounts << c.calculate_discount(self) and next if c.level == 2 && self.class.highest_item_in_cart == self
            discounts << calculate_coupon_discount(Cart.new(:coupon => c), c.products) 
          end
          # get the highest discount
          discounts.sort! {|x,y| y <=> x }
          disc = discounts.blank? ? 0.0 : discounts.first
        else
          return 0.0 if cart.coupon.banner_only || cart.coupon.level == 3 || (cart.coupon.level == 1 && cart.gross_price < cart.coupon.threshold)
          return cart.coupon.calculate_discount(self) if cart.coupon.level == 2 && self.class.highest_item_in_cart == self
          disc = calculate_coupon_discount(cart, cart.coupon.products)          
        end
      end
      if disc.to_f.round_to(2) > base_price
        @coupon_discount = base_price
      else
        @coupon_discount = disc.to_f.round_to(2)
      end  
      BigDecimal.new @coupon_discount.to_s
    end

    def availability_msg
      if store == 'custom'
        availability_message
      else
        store_values.key(store)
      end
    end

  	def saving_percentage
  		sp = ((msrp - price)/msrp * 100).round rescue 0
  		sp = 0 if sp < 0 || (sp.respond_to?(:nan?) && sp.nan?)
  		sp
  	end

    memoize :coupon_discount, :regular_price, :msrp, :outlet_price, :campaign_title, :config_name, :promo_text, :abs_sale_discount, :availability_msg

    def destroy
    	update_attribute :deleted, true
    end

    def avail?
      (availability == 1) || (availability == 3)
    end

    def in_stock?
      quantity > QUANTITY_THRESHOLD
    end

    def out_of_stock?
      !in_stock?
    end

  	def clearance_discontinued
  		life_cycle == "Clearance-Discontinued"
  	end

    def available?
      if is_er?
        (availability == 1 && price > 0 && start_date < Time.zone.now && end_date > Time.zone.now && active && !deleted)
      else
        (availability == 1 && in_stock? && regular_price > 0 && start_date < Time.zone.now && end_date > Time.zone.now && active && !deleted)      
      end
    end

    def er_available?
      if is_er?
        available? && (in_stock? || pre_order?)
      else
        available?
      end
  	end

  	def solr_available?
  		outlet? ? available? : related_available?
  	end

    def out_of_stock_but_available?
      is_ee? ? (availability == 1 && regular_price > 0 && start_date < Time.zone.now && end_date > Time.zone.now && active && !deleted && !(clearance_discontinued && out_of_stock?)) : er_available?
    end

    def report_available?
      ((availability == 1 || availability == 3) && start_date < Time.zone.now && end_date > Time.zone.now && active && !deleted)
    end

    def related_available?
      ((availability == 1 || availability == 3) && start_date < Time.zone.now && end_date > Time.zone.now && active && !deleted)
    end

    def idea_available?
      (availability != 0 && start_date < Time.zone.now && end_date > Time.zone.now && active && !deleted)
    end

    def campaign_available?
      ((availability == 1 || availability == 3) && regular_price > 0 && start_date < Time.zone.now && end_date > Time.zone.now && active && !deleted)
    end

    def inactive?
      availability == 0 || deleted || start_date > Time.zone.now || end_date < Time.zone.now || !active
    end

  	def pre_order?
  		is_er? && available? && pre_order
  	end

  	def future_product
  	  is_er? && !release_date.blank? && release_date > Time.zone.now 
  	end

  	def release_date_string
  		release_date && release_date > Time.zone.now ? release_date.strftime("%B %Y") : nil
  	end

    def designer_string
      read_attribute('designer')
    end

    def in_valid_campaign?
      campaigns_products.any? {|cp| cp.campaign.start_date <= Time.zone.now && cp.campaign.end_date >= Time.zone.now  && cp.active && !cp.campaign.deleted}
    end

    def suspended?
      start_date > Time.zone.now || end_date < Time.zone.now || availability != 1 || !active || deleted
    end

    def quantity_dropdown_values
      reload
      if quantity > 0 
        Array.new(quantity > MinimalCart::MAX_PER_ITEM ? MinimalCart::MAX_PER_ITEM : quantity){|i| i+1}
      else
        []
      end
    end

  	# wether or not product is an eclips machine, and thus qualifies for deferred payments
  	def eclips?
  		item_num == "655934" || item_num == "999999" || (item_num == "654427" && RAILS_ENV == 'development')
  	end

  	def vat_price(number)
  		@vat = Rails.cache.fetch("vat_value", :expires_in => 24.hours) do 
  			SystemSetting.find_by_name("vat") || 15.0
  		end
      (number.to_f * (1+@vat.to_f/100.0)).round_to(2)
  	end

  private

  	def saving_percentage_array
  		# 10% increments:
  		#a = Array.new(((((msrp - price)/msrp * 100).to_i rescue 0)/10.0).floor + 1){|x| x * 10} rescue [0]
  		# 5% increments:
  		a = Array.new((saving_percentage-saving_percentage%5)/5+1) {|x| x * 5}
  		# under 50% (5% for non-outlet): (85% is the highest):
  		threshold = outlet? ? 50 : 5
  		a.delete_if {|ar| (ar < threshold || ar > 85) && ar != 0}
  		a.shift unless a.length == 1
  		a
  	end

  	def set_outlet_since
  		if clearance
  			write_attribute(:outlet_since, Time.zone.now) if clearance_change == [false, true] || new_record?
  		end
  	end

    def calculate_coupon_discount(cart, products)
      return cart.coupon.calculate_discount(self) if cart.coupon.individual
      return (base_price * cart.coupon.disc_value/100) if (products.include?(self) || cart.coupon.level == 1) && cart.coupon.disc_type == 0
      return cart.coupon.disc_value if products.include?(self) && cart.coupon.disc_type == 1 
      return (cart.coupon.disc_value.to_f/cart.number_of_items.to_f).round_to(2) if cart.number_of_items > 0 && cart.coupon.level == 1 && cart.coupon.disc_type == 1
      0.0
    end

    def empty_cache
      flush_cache(true) if is_er? || in_valid_campaign?
    end

    def clear_all_products
      Rails.cache.delete("all_products")
      return
    end
  end
end
