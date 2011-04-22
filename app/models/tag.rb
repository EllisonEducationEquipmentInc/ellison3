class Tag
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  #include Mongoid::Associations::EmbeddedCallbacks
  
  include Sunspot::Mongoid
  
  extend EventCalendar::ClassMethods
  has_event_calendar :start_at_field  => 'calendar_start_date', :end_at_field => 'calendar_end_date'
  
  attr_accessor :embed_campaign
  
  TYPES = ["category", "subcategory", "product_line", "product_family", "theme", "subtheme", "curriculum", "subcurriculum", "designer", "artist", "grade_level", "release_date", "machine_compatibility", "material_compatibility", "size", "special"]
  HIDDEN_TYPES = ["exclusive", "calendar_event"]
  
  references_and_referenced_in_many :products, :index => true, :validate => false
  references_and_referenced_in_many :ideas, :index => true, :validate => false
  embeds_one :campaign
  
  embeds_many :compatibilities
  
  embeds_many :visual_assets do
    def current(time = Time.zone.now)
      ordered.select {|asset| asset.available?(time)}
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
  # system specific validations
  ELLISON_SYSTEMS.each do |system|
    validates :"start_date_#{system}", :"end_date_#{system}",  :presence => true, :if => Proc.new {|p| current_system == system}
  end
  validates_format_of :permalink, :with => /^[\w\d-]+$/
  validate :permalink_uniqueness

  after_validation :reindex?  
  before_save :inherit_system_specific_attributes
  before_save :run_callbacks_on_children
  
  before_validation :set_permalink
  after_save :maybe_index
  
  after_save :update_campaign, :unless => proc {disable_solr_indexing?}
  
  after_create :index!, :unless => proc {disable_solr_indexing?}

  field :name
  field :tag_type
  field :active, :type => Boolean, :default => true
  field :systems_enabled, :type => Array
  field :description
  field :permalink
  ELLISON_SYSTEMS.each do |system|
    field "start_date_#{system}".to_sym, :type => DateTime
    field "end_date_#{system}".to_sym, :type => DateTime
    field :"calendar_start_date_#{system}", :type => DateTime
    field :"calendar_end_date_#{system}", :type => DateTime
  end
  field :banner
  field :list_page_image
  field :medium_image
  field :all_day, :type => Boolean
  field :old_id, :type => Integer
  field :old_id_edu, :type => Integer
  field :color
  field :keywords
  # field :calendar_start_date, :type => DateTime
  # field :calendar_end_date, :type => DateTime
  
	field :created_by
	field :updated_by
  
  index :systems_enabled
  index :permalink
  index :tag_type
  index :active
  index :name
  index :old_id
  ELLISON_SYSTEMS.each do |system|
    index :"start_date_#{system}"
    index :"end_date_#{system}"
  end
  index :image_filename
  index :updated_at
  
  index [[:permalink, Mongo::ASCENDING], [:tag_type, Mongo::ASCENDING], [:active, Mongo::ASCENDING]]
  
  mount_uploader :image, GenericImageUploader 
  
  # scopes
  scope :active, :where => { :active => true }
  scope :inactive, :where => { :active => false }
  scope :not_hidden, :where => { :tag_type.nin => HIDDEN_TYPES }
  #scope :available, lambda { |sys = current_system| where(:active => true, :systems_enabled.in => [sys], :"start_date_#{sys}".lte => Time.zone.now, :"end_date_#{sys}".gte => Time.zone.now) }
  ELLISON_SYSTEMS.each do |sys|
    scope sys.to_sym, :where => { :systems_enabled.in => [sys] }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex.:  Tag.szus => scope for sizzix US tags
  end
  
  class << self
    
    def events_for_date_range(start_d, end_d, find_options = {})
      Tag.available.where(:"calendar_end_date_#{current_system}".gte => start_d.to_time.utc,  :"calendar_start_date_#{current_system}".lt => end_d.to_time.utc).asc(:"calendar_start_date_#{current_system}")
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
  
  searchable :auto_index => true, :auto_remove => true, :ignore_attribute_changes_of => ["updated_at", "product_ids", "idea_ids", "description", "permalink", "start_date_szus", "end_date_szus", "start_date_szuk", "end_date_szuk", "start_date_eeus", "end_date_eeus", "start_date_eeuk", "end_date_eeuk", "start_date_er", "end_date_er", "banner", "list_page_image", "medium_image", "all_day", "old_id", "old_id_edu", "color", "keywords", "calendar_start_date_szus", "calendar_end_date_szus", "calendar_start_date_szuk", "calendar_end_date_szuk", "calendar_start_date_eeus", "calendar_end_date_eeus", "calendar_start_date_eeuk", "calendar_end_date_eeuk", "calendar_start_date_er", "calendar_end_date_er", "image_filename"] do
    boolean :active
    text :name
    string :stored_name, :stored => true do
		  name
		end
    string :tag_type, :stored => true
  end
  
  def product_item_nums=(item_nums)
    products.concat(Product.where(:item_num.in => item_nums.split(/,\s*/)).to_a) unless item_nums.blank?
  end
  
  def product_item_nums
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
  
  def destroy
    update_attribute :active, false
  end
  
  def displayable?(sys = current_system, time = Time.zone.now)
		active && systems_enabled.include?(sys) && self.send("start_date_#{sys}") < time && self.send("end_date_#{sys}") > time
	end
	
private 

  def update_campaign
    if campaign? && Boolean.set(embed_campaign) && !campaign.blank? #&& !products.blank?
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
          self.products << product unless self.products.include?(product)
          product.save
        end
      else
        products.each do |product|
          c = product.campaigns.where( :_id => campaign.id).first || product.campaigns.build
          c.copy_common_attributes campaign
          c.id = campaign.id
          c.start_date = campaign.start_date
          c.end_date = campaign.end_date
          product.save
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
  
  def reindex?
	  @marked_for_auto_indexing = self.errors.blank? && self.changed? && self.changed.any? {|e| (["systems_enabled", "active"]).include?(e)}
	  @marked_for_scheduled_auto_indexing = self.changed.select {|e| e =~ /^(start|end)_date/}
	end
	
	def maybe_index
	  if @marked_for_auto_indexing
	    Rails.logger.info "REINDEX!!! Tag's products/ideas are scheduled for reindexing"
	    self.products.each {|e| e.delay.index!}
	    self.ideas.each {|e| e.delay.index!}
	    remove_instance_variable(:@marked_for_auto_indexing)
	  end
    index_dates = []
	  @marked_for_scheduled_auto_indexing && @marked_for_scheduled_auto_indexing.each do |d|
      if self.send(d).is_a?(DateTime) && !index_dates.include?(self.send(d).utc)
        scheduled_at = self.send(d).utc > Time.now.utc ? self.send(d) : Time.now
        Rails.logger.info "FUTURE REINDEX!!! scheduled at #{scheduled_at}"
        self.products.each {|e| e.delay(:run_at => scheduled_at).index!}
  	    self.ideas.each {|e| e.delay(:run_at => scheduled_at).index!}
        index_dates << self.send(d).utc
      end
	  end
    @marked_for_scheduled_auto_indexing = []
	end
	
	def run_callbacks_on_children
    self.visual_assets.each { |doc| doc.run_callbacks(:save) }
  end
end