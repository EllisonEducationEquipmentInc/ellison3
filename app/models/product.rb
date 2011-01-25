require 'carrierwave/orm/mongoid'
require 'digest/sha1'

class Product
	include EllisonSystem
	include Mongoid::Document
	# NOTE: to be able to skip Versioning and/or Timestamps, use my patched mongoid: git://github.com/computadude/mongoid.git
	include Mongoid::Timestamps
	include Mongoid::Paranoia
	
	include Sunspot::Mongoid
	
  # include Mongoid::Versioning
  # max_versions 5
	
	# To have all queries for a model "cache":
  #cache
	
	
	QUANTITY_THRESHOLD = 0
	LIFE_CYCLES = ['pre-release', 'available', 'discontinued', 'unvailable']
	
	cattr_accessor :retailer_discount_level
	
	# validations
	validates :name, :item_num, :life_cycle, :systems_enabled, :presence => true
	validates :related_product_tag, :object_id_validity => true, :allow_blank => true
	validates_presence_of :discount_category_id, :if => Proc.new {|obj| obj.systems_enabled && obj.systems_enabled.include?("er")}
  # validates_presence_of :volume, :if => Proc.new {|obj| obj.length.blank? || obj.width.blank? || obj.height.blank?}, :message => "Either volume or length + width + height is required" 
  # validates_presence_of :length, :width, :height, :if => Proc.new {|obj| obj.volume.blank?}, :message => "Either volume or length + width + height is required" 
	validates_inclusion_of :life_cycle, :in => LIFE_CYCLES, :message => "%s is not included in the list"
	validates_uniqueness_of :item_num
	validates_uniqueness_of :upc, :allow_blank => true
	validate :must_have_msrp
	
	validates_associated :tabs
	
	before_save :inherit_system_specific_attributes
	#before_save :clean_up_tags
	before_save :timestamp_outlet
	
	# system specific validations
	ELLISON_SYSTEMS.each do |system|
	  validates :"start_date_#{system}", :"end_date_#{system}",  :presence => true, :if => Proc.new {|p| current_system == system}
	end
	
	# field definitions
	field :name
	field :short_desc
	field :long_desc
	field :item_num
	field :upc
  field :quantity, :type => Integer, :default => 0
	field :minimum_quantity, :type => Integer, :default => 1
	field :weight, :type => Float, :default => 0.0
	field :active, :type => Boolean, :default => true
	field :outlet, :type => Boolean, :default => false
	field :outlet_since, :type => DateTime
	field :life_cycle
	field :systems_enabled, :type => Array
	field :related_products, :type => Array, :default => []
	field :related_product_tag
	field :tax_exempt, :type => Boolean, :default => false
	field :volume, :type => Float
	field :length, :type => Float
	field :width, :type => Float
	field :height, :type => Float
	field :keywords
	field :use_tabs, :type => Boolean, :default => false
	field :old_id, :type => Integer
	field :old_id_edu, :type => Integer
	field :old_id_szuk, :type => Integer
	field :old_id_er, :type => Integer
	
	
	field :item_code
	field :default_config, :type => Boolean, :default => false
	
	index :item_num, :unique => true, :background => true
	index :systems_enabled
	index :life_cycle
	index :active
	index :name
	index :old_id
	index :old_id_edu
	ELLISON_SYSTEMS.each do |system|
	  index :"start_date_#{system}"
	  index :"end_date_#{system}"
	end
	index :updated_at
	
	# associations
	embeds_many :campaigns do
    def current(time = Time.zone.now)
			@target.select {|campaign| campaign.available?(time)}
    end
  end
	embeds_many :tabs do
    def current
			ordered.select {|tab| tab.available?}.sort {|x,y| x.display_order <=> y.display_order}
    end

		def ordered
			@target.sort {|x,y| x.display_order <=> y.display_order}
		end

		def resort!(ids)
			@target.each {|t| t.display_order = ids.index(t.id.to_s)}
		end
  end
	embeds_many :images
	embeds_one :product_config
	
	references_and_referenced_in_many :tags, :index => true
	references_and_referenced_in_many :ideas, :index => true
  #references_many :order_items, :index => true
  #references_many :cart_items, :index => true
  
  referenced_in :discount_category
  
	# scopes
	scope :active, :where => { :active => true }
	scope :not_outlet, :where => { :outlet => false }
	scope :outlet, :where => { :outlet => true }
	scope :inactive, :where => { :active => false }
	
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :systems_enabled.in => [sys] }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex.:  Product.szus => scope for sizzix US products
	end
	
	class << self		
		def available
			active.where(:life_cycle.in => LIFE_CYCLES[0,3], :"start_date_#{current_system}".lte => Time.zone.now.change(:sec => 1), :"end_date_#{current_system}".gte => Time.zone.now.change(:sec => 1))
		end
		
		def find_by_item_num(item_num)
		  active.where(:item_num => item_num).cache.first
		end
		
		def related_to(exluded_product, outlet = false)
		  available.where(:_id.ne => exluded_product.id, :systems_enabled.in => [current_system], :outlet => outlet, :"quantity_#{is_us? ? 'us' : 'uk'}".gt => 0, :life_cycle.in => ['available']).limit(4)
		end
	end
		
	# define 
	#   system dependent attributes: start_date, end_date, description, distribution_life_cycle, distribution_life_cycle_ends, orderable
	#   currency dependent attributes: msrp, handling_price, wholesale_price (default: 50% of msrp if not defined)
	LOCALES_2_CURRENCIES.values.each do |currency|
		field "msrp_#{currency}".to_sym, :type => Float
		field "wholesale_price_#{currency}".to_sym, :type => Float
		field "handling_price_#{currency}".to_sym, :type => Float, :default => 0.0
	end
	ELLISON_SYSTEMS.each do |system|
	  field "orderable_#{system}", :type => Boolean
	  field "start_date_#{system}".to_sym, :type => DateTime
	  field "end_date_#{system}".to_sym, :type => DateTime
		field "description_#{system}".to_sym
		field "distribution_life_cycle_#{system}".to_sym
	  field "distribution_life_cycle_ends_#{system}".to_sym, :type => DateTime
	  field "availability_message_#{system}"
		LOCALES_2_CURRENCIES.values.each do |currency|
			field "price_#{system}_#{currency}".to_sym, :type => Float
		end
	end
	WAREHOUSES.each do |warehouse|
	  field "quantity_#{warehouse}".to_sym, :type => Integer, :default => 0
	  index "quantity_#{warehouse}".to_sym
	end

	mount_uploader :image, ImageUploader	
	
	# solr fields:
	searchable :auto_index => true, :auto_remove => true, :ignore_attribute_changes_of => WAREHOUSES.map {|e| "quantity_#{e}".to_sym} + [:updated_at] do
	  boolean :active
	  boolean :outlet
		text :tag_names do
			tags.map { |tag| tag.name }
		end
		text :name, :boost => 2
		#text :keywords, :boost => 1.5
		text :short_desc, :item_num
		string :life_cycle, :stored => true
		string :item_num, :stored => true
		string :medium_image, :stored => true
		string :stored_name, :stored => true do
		  name
		end
		string :systems_enabled, :multiple => true
    # integer :quantity, :stored => true
		integer :saving, :stored => true
		time :outlet_since
		LOCALES_2_CURRENCIES.values.each do |currency|
      float :"msrp_#{currency}" do
        msrp :currency => currency
      end
    end
    ELLISON_SYSTEMS.each do |system|
      # system specific facets: ex: theme_szus
      Tag.all_types.each do |e|
    		string :"#{e}_#{system}", :multiple => true, :references => TagFacet do
    		  send(e.to_s.pluralize, system).map {|t| "#{t.tag_type}~#{t.permalink}"}
    		end
     	end
     	time :"start_date_#{system}", :stored => true
      boolean :"orderable_#{system}", :stored => true do
        orderable?(system)
      end
      boolean :"listable_#{system}", :stored => true do
        listable?(system)
      end
      text :"description_#{system}" do 
        description :system => system
      end
      string :"public_life_cycle_#{system}", :stored => true do
        public_life_cycle system
      end
      string :"availability_message_#{system}", :stored => true do
        send "availability_message_#{system}"
      end
      string :sort_name do
  		  name.downcase.sub(/^(an?|the) /, '') rescue nil
  		end
  		integer :quantity_sold do
        Order.only("order_items").where("order_items.item_num" => item_num).inject(0) {|sum, o| sum += o.order_items.where({:item_num => item_num}).first.quantity}
  		end
      LOCALES_2_CURRENCIES.values.each do |currency|
        float :"price_#{system}_#{currency}" do
          price :currency => currency, :system => system
        end
        integer :"saving_#{system}_#{currency}" do
          saving(system, currency)
        end
      end
    end
	end
	
	# create tags association methods by name: @product.categories #=> Array of associated "category" tags for the current system. Pass optional system as an argument to get available tags for other systems:  @product.categories("szuk")
	Tag.all_types.each do |e|
		class_eval "def #{e.to_s.pluralize}(sys = current_system)\n tags.available(sys).send(\"#{e.to_s.pluralize}\") \n end"
	end
	
	def description(options = {})
		system = options[:system] || current_system
		send("description_#{system}") || send("description_er") || send("description_szus")
	end
	
	def description=(d)
		send("description_#{current_system}=", d) unless d.blank? || d == description_er
	end
	
	def msrp(options = {})
		currency = options[:currency] || current_currency
		send("msrp_#{currency}") || send("msrp_usd")
	end
	
	def wholesale_price(options = {})
	 	currency = options[:currency] || current_currency
		send("wholesale_price_#{currency}") || (msrp(:currency => currency)/2.0).round(2)
	end

	def handling_price=(p)
		send("handling_price_#{current_currency}=", p) unless p.blank?
	end
	
	def handling_price(options = {})
		currency = options[:currency] || current_currency
		send("handling_price_#{currency}") || send("handling_price_usd") || 0.0
	end

	def msrp=(p)
		send("msrp_#{current_currency}=", p)
	end
	
	def base_price(options = {})
		currency = options[:currency] || current_currency
		system = options[:system] || current_system
		if is_er?
		  wholesale_price(options)
		else
		  send("price_#{system}_#{currency}") || msrp(options)
		end
	end
	
	def price(options = {})
		time = options[:time] || Time.zone.now
		best_price = campaign_price(time) && base_price(options) > campaign_price(time) ? campaign_price(time) : base_price(options)
		if is_er? && !retailer_discount_level.blank?
		  rp = retailer_price(retailer_discount_level, options)
		  rp < best_price ? rp : best_price
		else
		  best_price
		end
	end
	
	def price=(p)
		send("price_#{current_system}_#{current_currency}=", p) unless p.blank?
	end

	def campaign_price(time = Time.zone.now)
		get_best_campaign(time).try :sale_price
	end

	alias :sale_price :campaign_price
	
	def saving(sys = current_system, curr = current_currency)
		sp = ((msrp(:currency => curr) - price(:currency => curr, :system => sys))/msrp(:currency => curr) * 100).round rescue 0
		sp = 0 if sp < 0 || (sp.respond_to?(:nan?) && sp.nan?)
		sp
	end
	
	def get_best_campaign(time = Time.zone.now)
		campaigns.current(time).sort {|x,y| x.sale_price <=> y.sale_price}.first
	end
	
	def retailer_price(discount_level = retailer_discount_level, options = {})
	  (wholesale_price(options) - retailer_discount(discount_level, options)).round(2)
	end
	
	def retailer_discount_percentage(discount_level = retailer_discount_level)
	  discount_category.try :discount, discount_level
	end
	
	def retailer_discount(discount_level = retailer_discount_level, options = {})
	  wholesale_price(options) * retailer_discount_percentage(discount_level)/100.0 rescue 0.0
	end
	
	def medium_image
		get_image(:medium)
	end
	
	def small_image
		get_image(:small)
	end
	
	def large_image
		get_image(:large)
	end	
	
	# Availability logic:
	# if life_cycle is either 'pre-release', 'available' or 'discontinued' then availability is determined by "orderable_#{current_system}" - (system specific) attribute
	# 
	# product visibility is determined by 'active', "start_date_#{current_system}", "end_date_#{current_system}" attributes
	
	# available for purchase on the website (regardless of available quantity)?
	def available?
		displayable? && orderable?
	end
	
	def orderable?(sys = current_system)
	  (self.send("orderable_#{sys}") && life_cycle != "unvailable") #|| life_cycle == "available" 
	end
	
	def not_reselable?
	  !available?
	end
	
	def unavailable?
		!available? || out_of_stock?
	end
	
	def suspended?
	  life_cycle == "unvailable"
	end
	
	# if product can be displayed on the product detail page (regardless of availablitity)
	def displayable?(sys = current_system)
	  active && systems_enabled.include?(sys) && self.send("start_date_#{sys}") < Time.zone.now && self.send("end_date_#{sys}") > Time.zone.now
	end
	
	# if product can be displayed on the product list page (regardless of availablitity) - current products whose life_cycle is NOT "unvailable"
	def listable?(sys = current_system)
	  displayable?(sys) && (LIFE_CYCLES[0,2].include?(life_cycle) || self.life_cycle == 'discontinued' && quantity(sys) > 0)
	end
	
	
	def quantity(sys = current_system)
	  if sys == "szus"
	    self.quantity_us + self.quantity_sz
	  else
	    sys == "eeus" || sys == "er" ? self.quantity_us : self.quantity_uk
	  end
	end
	
	def update_quantity(qty)
		skip_versioning_and_timestamps
    # TODO: build logic 
	end
	
	def decrement_quantity(qty)
		skip_versioning_and_timestamps
	  if is_sizzix? && qty > self.quantity_us
	    update_attributes :quantity_sz => self.quantity_sz + self.quantity_us - qty, :quantity_us => 0
	  else
	    is_us? ? update_attributes(:quantity_us => self.quantity_us - qty) : update_attributes(:quantity_uk => self.quantity_uk - qty)
	  end
	end
	
	def in_stock?
    available? && quantity > QUANTITY_THRESHOLD
  end
  
  def out_of_stock?
    available? && quantity <= QUANTITY_THRESHOLD
  end

	def pre_order?
		available? && life_cycle == "pre-release"
	end

  # system specific distribution life cycle - before its expiriation (distribution_life_cycle_ends_#{sys})
  def public_life_cycle(sys = current_system)
    read_attribute("distribution_life_cycle_#{sys}") if read_attribute("distribution_life_cycle_ends_#{sys}") > Time.zone.now
  rescue
    ''
  end
  
  # temporary many-to-many association fix until patch is released
	def my_tag_ids=(ids)
	  ids = ids.compact.uniq.map {|i| BSON::ObjectId(i)}
	  unless ids == self.tag_ids
	    self.tag_ids = []
	    self.tags = Tag.where(:_id.in => ids).uniq.map {|p| p}
	  end
	end
	
	def my_idea_ids=(ids)
	  ids = ids.compact.uniq.map {|i| BSON::ObjectId(i)}
	  unless ids == self.idea_ids
	    self.idea_ids = []
	    self.ideas = Idea.where(:_id.in => ids).uniq.map {|p| p}
	  end
	end
	
	def idea_ids
	  self['idea_ids'] || []
	end
	
	def related_product_item_nums
		read_attribute(:related_products).try :join, ", "
	end
	
	def related_product_item_nums=(product_item_nums)
		write_attribute(:related_products, product_item_nums.split(/,\s*/)) unless product_item_nums.nil?
	end
	
	# updates updated_at timestamp, and reindexes record. Validation callbacks are skipped
	def touch
	  self.updated_at = Time.zone.now
	  skip_versioning_and_timestamps
	  save :validate => false
	end
	
	def calculated_volume
	  self.volume || (self.width * self.height * self.length)
	end
	
	def size
	  product_config.additional_name if product_config && product_config.config_group == 'size'
	end
	
	def related_product_tag_name
	  return if self.related_product_tag.blank?
	  related_tag.try :name
	end
	
	def related_tag
	  if self.related_product_tag.valid_bson_object_id?
	    Tag.find(self.related_product_tag)
	  else
	    tags.available.send(is_ee? ? :subcurriculums : :themes).first || tags.available.categories.first
	  end
	end
	
	def four_related_products
	  related_tag.products.related_to(self, self.outlet) rescue []
	end
	
	def product_line
	  self.product_lines.first
	end
	
private 

  # automatically set system specific attributes (if not set) of all other enabled systems. Values are inherited from the current system
  # example: a new product is being created on SZUS. The new product will be pushed to szus and szuk. Those 2 systems are checked on the product admin form, and before save, SZUK will inherit the same attributes (which can be overridden by switching to szuk) 
  def inherit_system_specific_attributes
    self.systems_enabled.reject {|e| e == current_system}.each do |sys|
      self.send("start_date_#{sys}=", read_attribute("start_date_#{current_system}")) if read_attribute("start_date_#{sys}").blank?
      self.send("end_date_#{sys}=", read_attribute("end_date_#{current_system}")) if read_attribute("end_date_#{sys}").blank?
      self.send("orderable_#{sys}=", read_attribute("orderable_#{current_system}")) if read_attribute("orderable_#{sys}").nil?
      self.send("availability_message_#{sys}=", read_attribute("availability_message_#{current_system}")) if read_attribute("availability_message_#{sys}").blank?
      self.send("distribution_life_cycle_#{sys}=", read_attribute("distribution_life_cycle_#{current_system}")) if read_attribute("distribution_life_cycle_#{sys}").blank?
      self.send("distribution_life_cycle_ends_#{sys}=", read_attribute("distribution_life_cycle_ends_#{current_system}")) if read_attribute("distribution_life_cycle_ends_#{sys}").blank?
    end
  end

  def must_have_msrp
    errors.add(:msrp, "Make sure MSRP is defined for all available currencies in system #{current_system.upcase}") if currencies.any? {|c| self.send("msrp_#{c}").blank? || self.send("msrp_#{c}") < 0.01}
  end
  
	def get_image(version)
		if image?
			image_url(version)
		else
		  return image.default_url_edu_by_item_num(version) if is_ee? && FileTest.exists?("#{Rails.root}/public/#{image.default_url_edu_by_item_num(version)}")
		  return image.default_url_edu_by_item_num_downcase(version) if is_ee? && FileTest.exists?("#{Rails.root}/public/#{image.default_url_edu_by_item_num_downcase(version)}")
		  return image.default_url_edu_by_item_num_downcase_underscore(version) if is_ee? && FileTest.exists?("#{Rails.root}/public/#{image.default_url_edu_by_item_num_downcase_underscore(version)}")
		  return image.default_url_edu(version) if is_ee? && FileTest.exists?("#{Rails.root}/public/#{image.default_url_edu(version)}")
			FileTest.exists?("#{Rails.root}/public/#{image.default_url(version)}") ? image.default_url(version) : "/images/products/#{version}/noimage.jpg"
		end
	end
	
	# NOTE: needs git://github.com/computadude/mongoid.git
	def skip_versioning_and_timestamps
		self._skip_timestamps = true if respond_to?(:_skip_timestamps=)
		self._skip_versioning = true if respond_to?(:_skip_versioning=)
	end
	
	def clean_up_tags
	  self.tag_ids = self.tag_ids.compact.uniq
	end
	
	def timestamp_outlet
	  self.outlet_since ||= Time.zone.now if changed.include?("outlet") && self.outlet
	end
end