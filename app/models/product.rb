require 'carrierwave/orm/mongoid'
require 'digest/sha1'

class Product
  include EllisonSystem
  include Mongoid::Document
  # NOTE: to be able to skip Versioning and/or Timestamps, use my patched mongoid: git://github.com/computadude/mongoid.git
  include Mongoid::Timestamps
  include Mongoid::Paranoia
  
  include Sunspot::Mongoid
  
  extend ActiveSupport::Memoizable
  
  # include Mongoid::Versioning
  # max_versions 5
  
  # To have all queries for a model "cache":
  #cache
  
  
  QUANTITY_THRESHOLD = 0
  LIFE_CYCLES = ['pre-release', 'available', 'discontinued', 'unavailable']
  ITEM_TYPES = ['machine', 'bundle', 'die', 'accessory', 'supply']
  ITEM_GROUPS = ['Sizzix', 'Ellison', 'Third Party']
  
  cattr_accessor :retailer_discount_level
  
  # validations
  validates :name, :item_num, :life_cycle, :systems_enabled, :presence => true
  validates :related_product_tag, :object_id_validity => true, :allow_blank => true
  validates_presence_of :discount_category_id, :if => Proc.new {|obj| obj.systems_enabled && obj.systems_enabled.include?("erus")}
  validates_inclusion_of :life_cycle, :in => LIFE_CYCLES, :message => "%s is not included in the list"
  validates_uniqueness_of :item_num, :if => Proc.new {|obj| obj.new_record? || obj.item_num_changed?}, :case_sensitive => false
  validates_uniqueness_of :upc, :allow_blank => true, :if => Proc.new {|obj| obj.new_record? || obj.upc_changed?}, :case_sensitive => false
  validate :must_have_msrp
  # TODO: re-enable after migrations
  #validates_numericality_of :weight, :greater_than => 0.0
  validates_numericality_of :weight_kgs, :greater_than => 0.0, :allow_nil => true
  
  validates_associated :tabs
  
  before_save :inherit_system_specific_attributes
  before_save :quantity_cannot_be_negative
  before_save :timestamp_outlet
  before_save :remove_outlet_price #if outlet p becomes non-outlet
  before_save :reindex?
  after_save :maybe_index
  
  # system specific validations
  ELLISON_SYSTEMS.each do |system|
    validates :"start_date_#{system}", :"end_date_#{system}",  :presence => true, :if => Proc.new {|p| current_system == system}
    validates_numericality_of :"virtual_weight_#{system}", :greater_than_or_equal_to => 0.0, :allow_nil => true
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
  field :weight_kgs, :type => Float
  field :active, :type => Boolean, :default => true
  field :outlet, :type => Boolean, :default => false
  field :outlet_since, :type => DateTime
  field :life_cycle
  field :life_cycle_date, :type => Date
  field :systems_enabled, :type => Array
  field :related_products, :type => Array, :default => []
  field :related_product_tag
  field :tax_exempt, :type => Boolean, :default => false
  field :volume, :type => Float
  field :length, :type => Float
  field :width, :type => Float
  field :height, :type => Float
  field :keywords
  field :item_type
  field :item_group
  field :video
  field :use_tabs, :type => Boolean, :default => true
  field :instructions
  field :old_id, :type => Integer
  field :old_id_edu, :type => Integer
  field :old_id_szuk, :type => Integer
  field :old_id_er, :type => Integer
  
  field :created_by
  field :updated_by
  
  field :item_code
  field :default_config, :type => Boolean, :default => false
  
  index :item_num, :unique => true, :background => true
  index :systems_enabled
  index :life_cycle
  index :active
  index :name
  index :old_id
  index :old_id_edu
  index :old_id_szuk
  index :old_id_er
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
  
  references_and_referenced_in_many :tags, :index => true, :validate => false
  references_and_referenced_in_many :ideas, :index => true, :validate => false
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
    # displayable and life_cycle is in ['pre-release', 'available', 'discontinued']
    def available(sys = current_system, time = Time.zone.now)
      displayable(sys, time).where(:life_cycle.in => LIFE_CYCLES[0,3])
    end
    
    # displayable and life_cycle is in ['pre-release', 'available'], or discontinued but in-stock
    def listable(sys = current_system)
      displayable(sys).any_of({:life_cycle => 'discontinued', "$where" => sys == "szus" ? "this.quantity_sz > #{QUANTITY_THRESHOLD} || this.quantity_us > #{QUANTITY_THRESHOLD}" : "this.quantity_#{sys == "eeus" || sys == "erus" ? 'us' : 'uk'} > #{QUANTITY_THRESHOLD}"}, {:life_cycle.in => Product::LIFE_CYCLES[0,2]})
    end
    
    # enabled for current system and active, and between start and end date
    def displayable(sys = current_system, time = Time.zone.now)
      active.where(:systems_enabled.in => [sys], :"start_date_#{current_system}".lte => time.change(:sec => 1), :"end_date_#{current_system}".gte => time.change(:sec => 1))      
    end
    
    def find_by_item_num(item_num)
      active.where(:item_num => item_num).cache.first
    end
    
    def related_to(exluded_product, outlet = false)
      criteria = listable.where(:_id.ne => exluded_product.id).limit(5)
      #criteria = criteria.where(:outlet => outlet) if is_sizzix_us?
      criteria
    end
    
    def public_name
      self.name
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
    field "orderable_#{system}", :type => Boolean, :default => false
    field "start_date_#{system}".to_sym, :type => DateTime
    field "end_date_#{system}".to_sym, :type => DateTime
    field "description_#{system}".to_sym
    field "distribution_life_cycle_#{system}".to_sym
    field "distribution_life_cycle_ends_#{system}".to_sym, :type => DateTime
    field "availability_message_#{system}"
    LOCALES_2_CURRENCIES.values.each do |currency|
      field "price_#{system}_#{currency}".to_sym, :type => Float
    end
    field "virtual_weight_#{system}".to_sym, :type => Float
    field "virtual_weight_ends_#{system}".to_sym, :type => DateTime
  end
  WAREHOUSES.each do |warehouse|
    field "quantity_#{warehouse}".to_sym, :type => Integer, :default => 0
    index "quantity_#{warehouse}".to_sym
  end

  mount_uploader :image, ImageUploader  
  
  # solr fields:
  searchable :auto_index => false, :auto_remove => true, :ignore_attribute_changes_of => WAREHOUSES.map {|e| "quantity_#{e}".to_sym} + [:updated_at, :use_tabs, :instructions, :keywords] do
    boolean :active
    boolean :outlet
    text :tag_names do
      tags.available.map { |tag| tag.name }
    end
    text :name, :boost => 2
    text :keywords, :boost => 1.5
    text :short_desc, :item_num
    string :life_cycle, :stored => true
    string :item_num, :stored => true
    string :medium_image, :stored => true
    string :stored_name, :stored => true do
      name
    end
    string :item_group
    string :systems_enabled, :multiple => true
    # integer :quantity, :stored => true
    integer :saving, :stored => true
    time :outlet_since
    LOCALES_2_CURRENCIES.values.each do |currency|
      float :"msrp_#{currency}", :stored => true do
        msrp :currency => currency
      end
    end
    ELLISON_SYSTEMS.each do |system|
      # system specific facets: ex: theme_szus
      Tag.all_types.each do |e|
        string :"#{e}_#{system}", :multiple => true, :references => TagFacet do
          get_grouped_tags(system)[e]
        end
      end
      time :"start_date_#{system}", :stored => true
      boolean :"orderable_#{system}", :stored => true do
        orderable?(system)
      end
      boolean :"listable_#{system}", :stored => true do
        listable?(system)
      end
      # system specific field to be used for autosuggest
      text :"terms_#{system}" do
        "#{self.item_num} #{self.name} #{self.keywords} #{self.tags.not_hidden.available(system).map { |tag| tag.name } * ', '}" if listable?(system)
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
        Order.quanity_sold(item_num).first["value"]["quantity"].to_i rescue 0
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
    send("description_#{system}") || send("description_erus") || send("description_szus") || send("description_eeus")
  end
  
  def description=(d)
    send("description_#{current_system}=", d) unless d.blank? || d == description_erus
  end
  
  def msrp(options = {})
    currency = options[:currency] || current_currency
    send("msrp_#{currency}") || send("msrp_usd")
  end
  
  def wholesale_price(options = {})
    currency = options[:currency] || current_currency
    send("wholesale_price_#{currency}") || (msrp(:currency => currency)/2.0).round(2) rescue msrp(:currency => currency)
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
  
  def msrp_or_wholesale_price(options = {})
    is_er? ? wholesale_price(options) : msrp(options)
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
    if is_er? && !new_record? && !retailer_discount_level.blank?
      rp = retailer_price(retailer_discount_level, options)
      rp < best_price ? rp : best_price
    else
      best_price
    end
  end
  
  def price=(p)
    send("price_#{current_system}_#{current_currency}=", p) if p.present? && p.outlet
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
    (wholesale_price(options) - retailer_discount(discount_level, options)).round(2) rescue msrp
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
  
  def zoom_image
    get_image(:zoom)
  end
  
  # system specific virtual weight has precedence over actual weight
  def virtual_weight(sys = current_system)
    self.send("virtual_weight_#{sys}").present? && (self.send("virtual_weight_ends_#{sys}").blank? || self.send("virtual_weight_ends_#{sys}").present? && self.send("virtual_weight_ends_#{sys}") > Time.zone.now) ? self.send("virtual_weight_#{sys}") : self.weight
  end
  
  # Availability logic:
  # if life_cycle is either 'pre-release', 'available' or 'discontinued' then availability is determined by "orderable_#{current_system}" - (system specific) attribute
  # 
  # product visibility is determined by 'active', "start_date_#{current_system}", "end_date_#{current_system}" attributes
  
  # available for purchase on the website (regardless of available quantity)?
  def available?(sys = current_system)
    displayable?(sys) && orderable?(sys)
  end
  
  def orderable?(sys = current_system)
    (self.send("orderable_#{sys}") && life_cycle != "unavailable") #|| life_cycle == "available" 
  end
  
  def not_reselable?
    !available?
  end
  
  def unavailable?
    !available? || out_of_stock?
  end
  
  def suspended?
    life_cycle == "unavailable"
  end
  
  # if product can be displayed on the product detail page (regardless of availablitity)
  def displayable?(sys = current_system, time = Time.zone.now)
    active && systems_enabled.include?(sys) && self.send("start_date_#{sys}") < time && self.send("end_date_#{sys}") > time
  end
  
  # if product can be displayed on the catalog list page 
  def listable?(sys = current_system, qty = QUANTITY_THRESHOLD)
    displayable?(sys) && (LIFE_CYCLES[0,2].include?(life_cycle) || self.life_cycle == 'discontinued' && quantity(sys) > qty)
  end
  
  def quantity(sys = current_system)
    if sys == "szus"
      self.quantity_us + self.quantity_sz
    else
      sys == "eeus" || sys == "erus" ? self.quantity_us : self.quantity_uk
    end
  end
  
  def update_quantity(qty)
    skip_versioning_and_timestamps
    # TODO: build logic 
  end
  
  def decrement_quantity(qty)
    skip_versioning_and_timestamps
    if is_sizzix? && qty > self.quantity_us
      write_attributes :quantity_sz => self.quantity_sz + self.quantity_us - qty, :quantity_us => 0
    else
      is_us? ? write_attributes(:quantity_us => self.quantity_us - qty) : write_attributes(:quantity_uk => self.quantity_uk - qty)
    end
    save :validate => false
  end
  
  def in_stock?
    available? && quantity > QUANTITY_THRESHOLD
  end
  
  def out_of_stock?(sys = current_system, qty = QUANTITY_THRESHOLD)
    available?(sys) && quantity <= qty
  end

  def pre_order?(sys = current_system)
    available?(sys) && life_cycle == "pre-release"
  end
  
  def can_be_added_to_cart?
    if is_ee?
      listable?
    elsif is_er?
      in_stock? || pre_order?
    else
      in_stock?
    end
  end
  
  def get_grouped_tags(system = current_system)
    hash = {}
    tags.available(system).only(:tag_type).group.each do |group|
      hash[group["tag_type"]] = group["group"].map {|t| "#{t.tag_type}~#{t.permalink}"}
    end
    hash
  end
  
  memoize :get_grouped_tags
  
  # if pre_order and in stock and have enough qty
  # or product is available and in stock
  # or if backorder allowed, and product is listable
  # or if backorder not allowed, but product is in stock and have enough qty
  def can_be_purchased?(sys = current_system, qty_needed = 1)
    pre_order?(sys) && quantity(sys) >= qty_needed || backorder_allowed?(sys) && !pre_order?(sys) && out_of_stock? && listable? || 
      backorder_allowed?(sys) && !pre_order?(sys) && listable?(sys, qty_needed - 1) && quantity(sys) >= qty_needed || !backorder_allowed?(sys) && available?(sys) && quantity(sys) >= qty_needed
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
  
  def ellison?
    self.item_group == 'Ellison'
  end
  
  def sizzix?
    self.item_group == 'Sizzix'
  end
  
  def related_product_tag_name
    return if self.related_product_tag.blank?
    related_tag && "#{related_tag.try(:name)} (#{related_tag.try(:tag_type)})"
  end
  
  def related_tag
    Tag.available.find(self.related_product_tag)
  rescue
    tags.available.send(is_ee? || self.ellison? ? :subcurriculums : :subthemes).first || tags.available.send("#{'sub' unless is_ee?}categories").first
  end
  
  def four_related_criteria
    @four_related_criteria ||= related_tag.products.related_to(self, self.outlet) rescue []
  end
  
  def four_related_products
    skip_limit = four_related_criteria.count > 5 ? four_related_criteria.count - 5 : 1
    criteria = four_related_criteria.limit(5).skip(rand(skip_limit))
  rescue 
    []
  end
  
  def product_line
    self.product_lines.first
  end
  
  # returns true if product became out-of-stock, or in-stock
  def stock_status_changed?
    self.changes.select {|k,v| WAREHOUSES.map {|e| "quantity_#{e}"}.include?(k)}.values.any? {|e| e[0] > QUANTITY_THRESHOLD && e[1] <= QUANTITY_THRESHOLD || e[0] <= QUANTITY_THRESHOLD && e[1] > QUANTITY_THRESHOLD}
  end
  
  # url safe item_num. ex: 19557-1.25IN becomes 19557-1point25IN for friendy url's
  def url_safe_item_num
    self.item_num.gsub(".", "point")
  end
  
  def destroy
    update_attribute :active, false
  end
  
  def index_by_tag(tag)
    tag_dates = ELLISON_SYSTEMS.inject([]) {|a, e| tag.send("start_date_#{e}").present? ? a << tag.send("start_date_#{e}") : a; tag.send("end_date_#{e}").present? ? a << tag.send("end_date_#{e}") : a}
    tag_dates.uniq.each do |d|
      Rails.logger.info "TAG CAUSED SCHEDULED REINDEX!!! scheduled at #{d}"
      self.delay(:run_at => d).index!
    end
  end
  
  def calculate_coupon_discount(coupon)
    return if coupon.blank?
    p = if coupon.percent?
      self.msrp - (0.01 * coupon.discount_value * self.msrp).round(2)
    elsif coupon.absolute?
      self.msrp - coupon.discount_value > 0 ? self.msrp - coupon.discount_value : 0.0
    elsif coupon.fixed?
      coupon.discount_value
    end
    p < self.price ? p : self.price
  end
  
private 

  def quantity_cannot_be_negative
    WAREHOUSES.each do |warehouse|
      self.send("quantity_#{warehouse}=", 0) if self.send("quantity_#{warehouse}") < 0
    end
  end

  # automatically set system specific attributes (if not set) of all other enabled systems. Values are inherited from the current system
  # example: a new product is being created on SZUS. The new product will be pushed to szus and szuk. Those 2 systems are checked on the product admin form, and before save, SZUK will inherit the same attributes (which can be overridden by switching to szuk) 
  def inherit_system_specific_attributes
    self.systems_enabled.reject {|e| e == current_system}.each do |sys|
      %w(start_date end_date availability_message distribution_life_cycle distribution_life_cycle_ends).each do |m|
        self.send("#{m}_#{sys}=", read_attribute("#{m}_#{current_system}")) if read_attribute("#{m}_#{sys}").blank?
      end
      self.send("orderable_#{sys}=", read_attribute("orderable_#{current_system}")) if read_attribute("orderable_#{sys}").nil?
    end
  end

  def must_have_msrp
    errors.add(:msrp, "Make sure MSRP is defined for all available currencies in system #{current_system.upcase}") if currencies.any? {|c| self.send("msrp_#{c}").blank? || self.send("msrp_#{c}") < 0.01}
  end
  
  def get_image(version)
    if image?
      version.to_s == 'zoom' ? image_url : image_url(version) 
    else
      return image.default_url_edu_by_item_num(version) if (is_ee? || is_er?) && FileTest.exists?("#{Rails.root}/public/#{image.default_url_edu_by_item_num(version)}")
      return image.default_url_edu_by_item_num_downcase(version) if (is_ee? || is_er?) && FileTest.exists?("#{Rails.root}/public/#{image.default_url_edu_by_item_num_downcase(version)}")
      return image.default_url_edu_by_item_num_downcase_underscore(version) if (is_ee? || is_er?) && FileTest.exists?("#{Rails.root}/public/#{image.default_url_edu_by_item_num_downcase_underscore(version)}")
      return image.default_url_edu(version) if (is_ee? || is_er?) && FileTest.exists?("#{Rails.root}/public/#{image.default_url_edu(version)}")
      return image.default_url(version) if FileTest.exists?("#{Rails.root}/public/#{image.default_url(version)}")
      return "/images/products/#{version}/noimage.jpg" if FileTest.exists?("#{Rails.root}/public/images/products/#{version}/noimage.jpg")
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
  
  def remove_outlet_price
    self.price_szus_usd = nil if self.outlet_changed? && self.outlet_change == [true, false]
  end
  
  def reindex?
    @marked_for_auto_indexing = self.changed? && self.changed.any? {|e| (["systems_enabled", "active", "outlet", "life_cycle", "tag_ids"] + ELLISON_SYSTEMS.map {|s| ["orderable_#{s}"]}.flatten + LOCALES_2_CURRENCIES.values.map {|c| ["msrp_#{c}", "wholesale_price_#{c}"]}.flatten).include?(e)} || campaigns.any? {|c| c.reindex?} || stock_status_changed? || new_record?
    @scheduled_indexing_campaign_dates = campaigns.map {|c| c.scheduled_reindex}.flatten.uniq
    Rails.logger.info "!!! reindex? called @scheduled_indexing_campaign_dates: #{@scheduled_indexing_campaign_dates.inspect}"
    @marked_for_scheduled_auto_indexing = self.changed.select {|e| e =~ /^(start|end)_date/}
  end
  
  def maybe_index
    if @marked_for_auto_indexing
      self.delay.index!
      remove_instance_variable(:@marked_for_auto_indexing)
    end
    index_dates = []
    @marked_for_scheduled_auto_indexing && @marked_for_scheduled_auto_indexing.each do |d|
      if self.send(d).is_a?(DateTime) && !index_dates.include?(self.send(d).utc)
        scheduled_at = self.send(d).utc > Time.now.utc ? self.send(d) : Time.now
        Rails.logger.info "FUTURE REINDEX!!! scheduled at #{scheduled_at}"
        self.delay(:run_at => scheduled_at).index!
        index_dates << self.send(d).utc
      end
    end
    @scheduled_indexing_campaign_dates.each {|d| self.delay(:run_at => d > Time.now ? d : Time.now).index!}
    @marked_for_scheduled_auto_indexing = []
  end
  
end