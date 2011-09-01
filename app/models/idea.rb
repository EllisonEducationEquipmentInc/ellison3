require 'carrierwave/orm/mongoid'

class Idea
  include EllisonSystem
	include Mongoid::Document
	include Mongoid::Timestamps
	
	include Sunspot::Mongoid
	
	extend ActiveSupport::Memoizable
	
	validates :name, :idea_num, :systems_enabled, :presence => true
	validates :related_idea_tag, :object_id_validity => true, :allow_blank => true
	validates_uniqueness_of :idea_num, :if => Proc.new {|obj| obj.new_record? || obj.idea_num_changed?}, :case_sensitive => false
	
	before_save :inherit_system_specific_attributes
	#before_save :clean_up_tags
	before_save :reindex?, :unless => proc {disable_solr_indexing?}
	after_save :maybe_index, :unless => proc {disable_solr_indexing?}
	
	# system specific validations
	ELLISON_SYSTEMS.each do |system|
	  validates :"start_date_#{system}", :"end_date_#{system}",  :presence => true, :if => Proc.new {|p| current_system == system}
	end
	
	# field definitions
	field :name
	field :idea_num
	field :active, :type => Boolean, :default => true
	field :systems_enabled, :type => Array
	field :objective
	field :keywords
	field :old_id, :type => Integer
	field :old_id_edu, :type => Integer
	field :old_id_eeuk, :type => Integer
	field :old_id_szuk, :type => Integer
	field :long_desc
	field :grade_level, :type => Array
	field :related_idea_tag
	field :use_tabs, :type => Boolean, :default => true
	field :video
	field :item_group
	field :instructions
  
	
	field :created_by
	field :updated_by
	
	index :idea_num, :unique => true, :background => true
	index :systems_enabled
	index :active
	index :name
	index :old_id
	index :old_id_edu
	ELLISON_SYSTEMS.each do |system|
	  index :"start_date_#{system}"
	  index :"end_date_#{system}"
	end
	index :updated_at
	
	index [[:idea_num, Mongo::ASCENDING], [:name, Mongo::ASCENDING], [:short_desc, Mongo::ASCENDING]]
	
	alias :item_num :idea_num
	
	embeds_many :tabs do
    def current
			ordered.select {|tab| tab.available?} #.sort {|x,y| x.display_order <=> y.display_order}
    end

		def ordered
			@target.sort {|x,y| x.display_order <=> y.display_order}
		end

		def resort!(ids)
			@target.each {|t| t.display_order = ids.index(t.id.to_s)}
		end
  end
	embeds_many :images
	
	references_and_referenced_in_many :tags, :index => true, :validate => false
	references_and_referenced_in_many :products, :index => true, :validate => false
  
	# scopes
	scope :active, :where => { :active => true }
	scope :inactive, :where => { :active => false }
	
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :systems_enabled.in => [sys] }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex.:  Product.szus => scope for sizzix US products
	end
	
	class << self		
		def available(sys = current_system)
			active.where(:systems_enabled.in => [sys], :"start_date_#{current_system}".lte => Time.zone.now.change(:sec => 1), :"end_date_#{current_system}".gte => Time.zone.now.change(:sec => 1))
		end
		
		def find_by_idea_num(idea_num)
		  active.where(:idea_num => idea_num).cache.first
		end
		
		def public_name
		  is_ee? ? 'Lesson' : 'Project'
		end
	end

	ELLISON_SYSTEMS.each do |system|
	  field "start_date_#{system}".to_sym, :type => DateTime
	  field "end_date_#{system}".to_sym, :type => DateTime
		field "description_#{system}".to_sym
		field "distribution_life_cycle_#{system}".to_sym
	  field "distribution_life_cycle_ends_#{system}".to_sym, :type => DateTime
	end

	mount_uploader :image, ImageUploader
	
	# solr fields:
	searchable :auto_index => false, :auto_remove => true, :ignore_attribute_changes_of => [:updated_at, :use_tabs] do
	  time :last_indexed_at, :stored => true do
      Time.now
    end
    boolean :active
		text :tag_names do
			tags.available.map { |tag| tag.name }
		end
		text :name, :boost => 2
		text :idea_num
		text :keywords, :boost => 1.5
		string :idea_num, :stored => true
		string :medium_image, :stored => true
		string :small_image, :stored => true
		string :stored_name, :stored => true do
		  name
		end
		string :item_group
    string :systems_enabled, :multiple => true, :stored => true
    string :tag_ids, :multiple => true, :stored => true
    string :product_ids, :multiple => true, :stored => true
    ELLISON_SYSTEMS.each do |system|
      # system specific facets: ex: theme_szus
      Tag.all_types.each do |e|
    		string :"#{e}_#{system}", :multiple => true, :references => TagFacet do
    		  get_grouped_tags(system)[e]
    		end
     	end
     	time :"start_date_#{system}", :stored => true
      text :"description_#{system}" do 
        description :system => system
      end
      text :"terms_#{system}" do
        "#{self.idea_num} #{self.name} #{self.keywords} #{self.tags.not_hidden.available(system).map { |tag| tag.name } * ', '}" if listable?(system)
      end
      string :"public_life_cycle_#{system}", :stored => true do
        public_life_cycle system
      end
      string :sort_name do
  		  name.downcase.sub(/^(an?|the) /, '') rescue nil
  		end
  		boolean :"listable_#{system}", :stored => true do
        listable?(system)
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
	
	def my_product_ids=(ids)
	  ids = ids.compact.uniq.map {|i| BSON::ObjectId(i)}
	  unless ids == self.product_ids
	    self.product_ids = []
	    self.products = Product.where(:_id.in => ids).uniq.map {|p| p}
	  end
	end
	
	def product_ids
	  self['product_ids'] || []
	end
	
	# updates updated_at timestamp, and reindexes record. Validation callbacks are skipped
	def touch
	  self.updated_at = Time.zone.now
	  skip_versioning_and_timestamps
	  save :validate => false
	end

  def listable?(sys = current_system)
	  active && systems_enabled.include?(sys) && self.send("start_date_#{sys}") < Time.zone.now && self.send("end_date_#{sys}") > Time.zone.now
	end
	
	def item_code
	  self.idea_num #.gsub(/^L/, "")
	end
	
	def ellison?
	  self.item_group == 'Ellison'
	end
	
	def sizzix?
	  self.item_group == 'Sizzix'
	end
	
	def related_idea_tag_name
	  return if self.related_idea_tag.blank?
	  related_tag.try :name
	end
	
	def related_tag
	  Tag.available.find(self.related_idea_tag)
	rescue
	  tags.available.send(is_ee? || ellison? ? is_ee_uk? ? :curriculums : :subcurriculums : :themes).first
	end
	
	def four_related_criteria
	  @four_related_criteria ||= self.class.available.where(:_id.ne => self.id, :tag_ids.in => [related_tag.id]) rescue []
	end
	
	def four_related_ideas
	  skip_limit = four_related_criteria.count > 5 ? four_related_criteria.count - 5 : 1
	  criteria = four_related_criteria.limit(5).skip(rand(skip_limit))	  
	rescue 
	  []
	end
	
	def destroy
    update_attribute :active, false
  end
  
  def index_by_tag(tag)
    tag_dates = ELLISON_SYSTEMS.inject([]) {|a, e| tag.send("start_date_#{e}").present? ? a << tag.send("start_date_#{e}") : a; tag.send("end_date_#{e}").present? ? a << tag.send("end_date_#{e}") : a}
    tag_dates.uniq.each do |d|
      Rails.logger.info "TAG CAUSED SCHEDULED REINDEX!!! scheduled at #{d}"
      self.delay(:run_at => d).index
    end
  end
  
  def displayable?(sys = current_system, time = Time.zone.now)
		active && systems_enabled.include?(sys) && self.send("start_date_#{sys}") < time && self.send("end_date_#{sys}") > time
	end
	
	def get_grouped_tags(system = current_system)
    hash = {}
    tags.available(system).only(:tag_type).group.each do |group|
      hash[group["tag_type"]] = group["group"].map {|t| "#{t.tag_type}~#{t.permalink}"}
    end
    hash
  end
  
  def has_zoom?
    get_image(:zoom).present? && !get_image(:zoom).include?("noimage")
  end
  
  memoize :get_grouped_tags
  
private 

  # automatically set system specific attributes (if not set) of all other enabled systems. Values are inherited from the current system
  # example: a new product is being created on SZUS. The new product will be pushed to szus and szuk. Those 2 systems are checked on the product admin form, and before save, SZUK will inherit the same attributes (which can be overridden by switching to szuk) 
  def inherit_system_specific_attributes
    self.systems_enabled.reject {|e| e == current_system}.each do |sys|
      self.send("start_date_#{sys}=", read_attribute("start_date_#{current_system}")) if read_attribute("start_date_#{sys}").blank?
      self.send("end_date_#{sys}=", read_attribute("end_date_#{current_system}")) if read_attribute("end_date_#{sys}").blank?
      self.send("distribution_life_cycle_#{sys}=", read_attribute("distribution_life_cycle_#{current_system}")) if read_attribute("distribution_life_cycle_#{sys}").blank?
      self.send("distribution_life_cycle_ends_#{sys}=", read_attribute("distribution_life_cycle_ends_#{current_system}")) if read_attribute("distribution_life_cycle_ends_#{sys}").blank?
    end
  end

	def get_image(version)
		if image?
      version.to_s == 'zoom' ? image_url : image_url(version) 
		else
		  return image.default_url_edu(version) if (is_ee? || is_er?) && FileTest.exists?("#{Rails.root}/public/#{image.default_url_edu(version)}")
			FileTest.exists?("#{Rails.root}/public/#{image.default_url(version)}") ? image.default_url(version) : "/images/ideas/#{version}/noimage.jpg"
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
	
	def reindex?
	  @marked_for_auto_indexing = self.changed? && self.changed.any? {|e| (["systems_enabled", "active", "idea_num", "name", "item_group", "keywords"]).include?(e)}
	  @marked_for_scheduled_auto_indexing = self.changed.select {|e| e =~ /^(start|end)_date/}
	end
	
	def maybe_index
	  if @marked_for_auto_indexing
	    self.delay.index
	    remove_instance_variable(:@marked_for_auto_indexing)
	  end
	  index_dates = []
	  @marked_for_scheduled_auto_indexing && @marked_for_scheduled_auto_indexing.each do |d|
      if (self.send(d).is_a?(DateTime) || self.send(d).is_a?(ActiveSupport::TimeWithZone) || self.send(d).is_a?(Time)) && !index_dates.include?(self.send(d).utc)
        scheduled_at = self.send(d).utc > Time.now.utc ? self.send(d) : Time.now
        Rails.logger.info "FUTURE REINDEX!!! scheduled at #{scheduled_at}"
        self.delay(:run_at => scheduled_at).index
        index_dates << self.send(d).utc
      end
	  end
    @marked_for_scheduled_auto_indexing = []
	end
end
