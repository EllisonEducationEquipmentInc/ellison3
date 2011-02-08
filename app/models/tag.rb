class Tag
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Associations::EmbeddedCallbacks
  
  extend EventCalendar::ClassMethods
  has_event_calendar :start_at_field  => 'calendar_start_date', :end_at_field => 'calendar_end_date'
  
  attr_accessor :embed_campaign
  
  TYPES = ["artist", "category", "curriculum", "designer", "machine_compatibility", "material_compatibility", "product_family", "product_line", "special", "subcategory", "subcurriculum", "subtheme", "theme", "release_date", "size"]
  HIDDEN_TYPES = ["exclusive", "calendar_event"]
  
  references_and_referenced_in_many :products, :index => true
  references_and_referenced_in_many :ideas, :index => true
  embeds_one :campaign
  
  embeds_many :compatibilities
  
  embeds_many :visual_assets do
    def current
      ordered.select {|asset| asset.available?}
    end

    def ordered
      @target.sort {|x,y| x.display_order <=> y.display_order}
    end

    def resort!(ids)
      @target.each {|t| t.display_order = ids.index(t.id.to_s)}
    end
  end
  
  accepts_nested_attributes_for :visual_assets, :allow_destroy => true, :reject_if => proc { |attributes| attributes['name'].blank?}
  validates_associated :visual_assets
  
  accepts_nested_attributes_for :compatibilities, :allow_destroy => true, :reject_if => proc { |attributes| attributes['tag_id'].blank?}
  validates_associated :compatibilities
  
  validates :name, :tag_type, :systems_enabled, :permalink, :presence => true
  validates_format_of :permalink, :with => /^[\w\d-]+$/
  validate :permalink_uniqueness
  
  before_save :inherit_system_specific_attributes
  before_validation :set_permalink
  after_save :update_campaign
  
  field :name
  field :tag_type
  field :active, :type => Boolean, :default => true
  field :systems_enabled, :type => Array
  field :description
  field :permalink
  ELLISON_SYSTEMS.each do |system|
    field "start_date_#{system}".to_sym, :type => DateTime
    field "end_date_#{system}".to_sym, :type => DateTime
  end
  field :banner
  field :list_page_image
  field :medium_image
  field :all_day, :type => Boolean
  field :old_id, :type => Integer
  field :old_id_edu, :type => Integer
  field :color
  field :keywords
  
  index :systems_enabled
  index :permalink
  index :tag_type
  index :active
  index :name
  index :old_id
  ELLISON_SYSTEMS.each do |system|
    index :"start_date_#{system}"
    index :"end_date_#{system}"
    field :"calendar_start_date_#{system}", :type => DateTime
    field :"calendar_end_date_#{system}", :type => DateTime
  end
  index :image_filename
  index :updated_at
  
  mount_uploader :image, GenericImageUploader 
  
  # scopes
  scope :active, :where => { :active => true }
  scope :inactive, :where => { :active => false }
  #scope :available, lambda { |sys = current_system| where(:active => true, :systems_enabled.in => [sys], :"start_date_#{sys}".lte => Time.zone.now, :"end_date_#{sys}".gte => Time.zone.now) }
  ELLISON_SYSTEMS.each do |sys|
    scope sys.to_sym, :where => { :systems_enabled.in => [sys] }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex.:  Tag.szus => scope for sizzix US tags
  end
  
  class << self
    
    def events_for_date_range(start_d, end_d, find_options = {})
      Tag.available.calendar_events
    end
    
    def all_types
      Tag::TYPES + Tag::HIDDEN_TYPES
    end
      
    def available(sys = current_system)
      active.where(:systems_enabled.in => [sys], :"start_date_#{sys}".lte => Time.zone.now.change(:sec => 1), :"end_date_#{sys}".gte => Time.zone.now.change(:sec => 1))
    end
    
    def keywords(sys = current_system)
      available(sys).where(:tag_type.nin => HIDDEN_TYPES)
    end
    
    def have_image(sys = current_system)
      keywords(sys).excludes(:image_filename => nil)
    end
    
    def find_by_permalink(facet, permalink)
      active.where(:tag_type => facet.to_s.gsub(Regexp.new("_#{current_system}$"), ""), :permalink => permalink).cache.first
    end
  end
  
  all_types.each do |type|
    scope type.pluralize.to_sym, :where => { :tag_type => type }  # scope :calendar_events, :where => { :tag_type => "calendar_event" } #dynaically create a scope for each type. ex.:  Tag.calendar_events => scope for calendar event tags
  end
  
  def calendar_start_date
    send(:"calendar_start_date_#{current_system}")
  end
  
  def calendar_end_date
    send(:"calendar_end_date_#{current_system}")
  end
  
  def facet_param
    tag_type.to_s.gsub(/_(#{ELLISON_SYSTEMS.join("|")})$/, "") + "~" + permalink
  end
  
  # temporary many-to-many association fix until patch is released
  def my_product_ids=(ids)
    ids = ids.compact.uniq.map {|i| BSON::ObjectId(i)}
    unless ids == self.product_ids
      self.product_ids = []
      self.products = Product.where(:_id.in => ids).uniq.map {|p| p}
    end
  end

  # temporary many-to-many association fix until patch is released  
  def my_idea_ids=(ids)
    ids = ids.compact.uniq.map {|i| BSON::ObjectId(i)}
    unless ids == self.idea_ids
      self.idea_ids = []
      self.ideas = Idea.where(:_id.in => ids).uniq.map {|p| p}
    end
  end
  
  def campaign?
    self.tag_type == "special" #|| self.tag_type == "exclusive"
  end
  
  def list_page_img
    image? ? image_url(:medium) : self.list_page_image
  end

  def adjust_all_day_dates
    if self.tag_type == 'calendar_event' && self.all_day
      original_system = current_system
      ELLISON_SYSTEMS.each do |sys|
        set_current_system sys
        self.send(:"calendar_start_date_#{sys}=", self.send(:"calendar_start_date_#{sys}").beginning_of_day) if self.send(:"calendar_start_date_#{sys}").present?
    
        if self.send(:"calendar_end_date_#{sys}").present?
          self.send(:"calendar_end_date_#{sys}=", self.send(:"calendar_end_date_#{sys}").beginning_of_day + 1.day - 1.second)
        else
          self.send(:"calendar_end_date_#{sys}=", self.send(:"calendar_start_date_#{sys}").beginning_of_day + 1.day - 1.second) if self.send(:"calendar_start_date_#{sys}").present?
        end
      end
      set_current_system original_system
    end
  end
  
private 

  def update_campaign
    if campaign? && Boolean.set(embed_campaign) && !campaign.blank? && !products.blank?
      Rails.logger.info "!!! updating tag's campaign"
      # TODO: DRY
      if campaign.individual
        campaign.individual_discounts.each do |individual_discount|
          product = Product.find(individual_discount.product_id) rescue next
          c = product.campaigns.where( :_id => campaign.id).first || product.campaigns.build
          c.copy_common_attributes campaign
          c.id = campaign.id
          c.discount_type = individual_discount.discount_type
          c.discount = individual_discount.discount
          c.individual_discounts = []
          c.start_date = campaign.start_date
          c.end_date = campaign.end_date
          c.save
        end
      else
        products.each do |product|
          c = product.campaigns.where( :_id => campaign.id).first || product.campaigns.build
          c.copy_common_attributes campaign
          c.id = campaign.id
          c.start_date = campaign.start_date
          c.end_date = campaign.end_date
          c.save
        end
      end
    end
  end

  def permalink_uniqueness
    errors.add(:permalink, "There's another #{self.tag_type.humanize} tag record with permalink: #{self.permalink}") if self.class.where(:tag_type => self.tag_type, :permalink => self.permalink, :_id.ne => self.id).count > 0
  end

  def set_permalink
    self.permalink = self.name.parameterize 
  end

  def inherit_system_specific_attributes
    self.systems_enabled.reject {|e| e == current_system}.each do |sys|
      %w(start_date end_date).each do |m|
        self.send("#{m}_#{sys}=", read_attribute("#{m}_#{current_system}")) if read_attribute("#{m}_#{sys}").blank?
      end      
    end
  end
end