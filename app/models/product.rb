require 'carrierwave/orm/mongoid'
require 'digest/sha1'

class Product
	include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
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
	
	# validations
	validates :name, :item_num, :life_cycle, :systems_enabled, :presence => true
	validates_presence_of :volume, :if => Proc.new {|obj| obj.length.blank? || obj.width.blank? || obj.height.blank?}, :message => "Either volume or length + width + height is required" 
	validates_presence_of :length, :width, :height, :if => Proc.new {|obj| obj.volume.blank?}, :message => "Either volume or length + width + height is required" 
	validates_inclusion_of :life_cycle, :in => LIFE_CYCLES, :message => "%s is not included in the list"
	validates_uniqueness_of :item_num
	validates_uniqueness_of :upc, :allow_blank => true
	validate :must_have_msrp
	
	before_save :inherit_system_specific_attributes
	before_save :clean_up_tags
	
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
	field :weight, :type => Float, :default => 0.0
	field :active, :type => Boolean, :default => true
	field :life_cycle
	field :systems_enabled, :type => Array
	field :tax_exempt, :type => Boolean, :default => false
	field :volume, :type => Float
	field :length, :type => Float
	field :width, :type => Float
	field :height, :type => Float
	
	index :item_num, :unique => true, :background => true
	index :systems_enabled
	index :life_cycle
	index :active
	index :name
	index :quantity
	ELLISON_SYSTEMS.each do |system|
	  index :"start_date_#{system}"
	  index :"end_date_#{system}"
	end
	
	# associations
	embeds_many :campaigns do
    def current(time = Time.zone.now)
			@target.select {|campaign| campaign.available?(time)}
    end
  end
	embeds_many :tabs do
    def current
			@target.select {|tab| tab.available?}.sort {|x,y| x.display_order <=> y.display_order}
    end

		def ordered
			@target.sort {|x,y| x.display_order <=> y.display_order}
		end

		def resort!(ids)
			@target.each {|t| t.display_order = ids.index(t.id.to_s)}
		end
  end
	embeds_many :images
	
	references_many :tags, :stored_as => :array, :inverse_of => :products, :index => true
  	
	# scopes
	scope :active, :where => { :active => true }
	scope :inactive, :where => { :active => false }
	
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :systems_enabled.in => [sys] }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex.:  Product.szus => scope for sizzix US products
	end
	
	class << self		
		def available
			active.where(:life_cycle.in => LIFE_CYCLES[0,3], :"start_date_#{current_system}".lte => Time.zone.now, :"end_date_#{current_system}".gte => Time.zone.now)
		end
	end
		
	# define 
	#   system dependent attributes: start_date, end_date, description, distribution_life_cycle, distribution_life_cycle_ends, orderable
	#   currency dependent attributes: msrp, handling_price
	LOCALES_2_CURRENCIES.values.each do |currency|
		field "msrp_#{currency}".to_sym, :type => Float
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

	mount_uploader :image, ImageUploader	
	
	# solr fields:
	searchable :auto_index => true, :auto_remove => true do
	  boolean :active
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
		integer :quantity, :stored => true
		LOCALES_2_CURRENCIES.values.each do |currency|
      float :"msrp_#{currency}" do
        msrp :currency => currency
      end
    end
    ELLISON_SYSTEMS.each do |system|
      # system specific facets: ex: theme_szus
      Tag::TYPES.each do |e|
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
      end
    end
	end
	
	# create tags association methods by name: @product.categories #=> Array of associated "category" tags for the current system. Pass optional system as an argument to get available tags for other systems:  @product.categories("szuk")
	Tag::TYPES.each do |e|
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
		send("price_#{system}_#{currency}") || msrp(options)
	end
	
	def price(options = {})
		time = options[:time] || Time.zone.now
		campaign_price(time) && base_price(options) > campaign_price(time) ? campaign_price(time) : base_price(options)
	end
	
	def price=(p)
		send("price_#{current_system}_#{current_currency}=", p) unless p.blank?
	end
	
	def custom_price
    @custom_price ||= custom_prices[id]
  end
  
  def custom_price=(p)
    @custom_price = p.to_f.round_to(2)
  end

	def campaign_price(time = Time.zone.now)
		get_best_campaign(time).try :sale_price
	end

	alias :sale_price :campaign_price
	
	def get_best_campaign(time = Time.zone.now)
		campaigns.current(time).sort {|x,y| x.sale_price <=> y.sale_price}.first
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
	  displayable?(sys) && LIFE_CYCLES[0,3].include?(life_cycle)
	end
	
	def update_quantity(qty)
		skip_versioning_and_timestamps
		update_attributes :quantity => qty
	end
	
	def decrement_quantity(qty)
		skip_versioning_and_timestamps
		update_attributes :quantity => self.quantity - qty
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
	  self.tag_ids = []
	  self.tags = Tag.where(:_id.in => ids.compact.uniq.map {|i| BSON::ObjectId(i)}).uniq.map {|p| p}
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

private 

  # automatically set system specific attributes (if not set) of all other enabled systems. Values are inherited from the current system
  # example: a new product is being created on SZUS. The new product will be pushed to szus and szuk. Those 2 systems are checked on the product admin form, and before save, SZUK will inherit the same attributes (which can be overridden by switching to szuk) 
  def inherit_system_specific_attributes
    self.systems_enabled.reject {|e| e == current_system}.each do |sys|
      self.send("start_date_#{sys}=", read_attribute("start_date_#{current_system}")) if read_attribute("start_date_#{sys}").blank?
      self.send("end_date_#{sys}=", read_attribute("end_date_#{current_system}")) if read_attribute("end_date_#{sys}").blank?
      self.send("orderable_#{sys}=", read_attribute("orderable_#{current_system}")) if read_attribute("orderable_#{sys}").blank?
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
			FileTest.exists?("#{Rails.root}/public/#{image.default_url(version)}") ? image.default_url(version) : "/images/products/#{version}/noimage.jpg"
		end
	end
	
	# NOTE: needs git://github.com/computadude/mongoid.git
	def skip_versioning_and_timestamps
		self._skip_timestamps = self._skip_versioning = true
	end
	
	def clean_up_tags
	  self.tag_ids = self.tag_ids.compact.uniq
	end
end