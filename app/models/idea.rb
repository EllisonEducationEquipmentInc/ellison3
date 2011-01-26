require 'carrierwave/orm/mongoid'

class Idea
  include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	include Mongoid::Timestamps
	
	include Sunspot::Mongoid
	
	validates :name, :idea_num, :systems_enabled, :presence => true
	validates :related_idea_tag, :object_id_validity => true, :allow_blank => true
	validates_uniqueness_of :idea_num
	
	before_save :inherit_system_specific_attributes
	#before_save :clean_up_tags
	
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
	field :long_desc
	field :grade_level, :type => Array
	field :related_idea_tag
	field :use_tabs, :type => Boolean, :default => false
	
	index :idea_num, :unique => true, :background => true
	index :systems_enabled
	index :active
	index :name
	index :old_id
	ELLISON_SYSTEMS.each do |system|
	  index :"start_date_#{system}"
	  index :"end_date_#{system}"
	end
	index :updated_at
	
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
	
	references_and_referenced_in_many :tags, :index => true
	references_and_referenced_in_many :products, :index => true
  
	# scopes
	scope :active, :where => { :active => true }
	scope :inactive, :where => { :active => false }
	
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :systems_enabled.in => [sys] }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex.:  Product.szus => scope for sizzix US products
	end
	
	class << self		
		def available
			active.where(:"start_date_#{current_system}".lte => Time.zone.now.change(:sec => 1), :"end_date_#{current_system}".gte => Time.zone.now.change(:sec => 1))
		end
		
		def find_by_idea_num(idea_num)
		  active.where(:idea_num => idea_num).cache.first
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
	searchable :auto_index => true, :auto_remove => true, :ignore_attribute_changes_of => [:updated_at] do
	  boolean :active
		text :tag_names do
			tags.map { |tag| tag.name }
		end
		text :name, :boost => 2
		text :idea_num
		#text :keywords, :boost => 1.5
		string :idea_num, :stored => true
		string :medium_image, :stored => true
		string :stored_name, :stored => true do
		  name
		end
		string :systems_enabled, :multiple => true
    ELLISON_SYSTEMS.each do |system|
      # system specific facets: ex: theme_szus
      Tag.all_types.each do |e|
    		string :"#{e}_#{system}", :multiple => true, :references => TagFacet do
    		  send(e.to_s.pluralize, system).map {|t| "#{t.tag_type}~#{t.permalink}"}
    		end
     	end
     	time :"start_date_#{system}", :stored => true
      text :"description_#{system}" do 
        description :system => system
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
		send("description_#{system}") || send("description_er") || send("description_szus")
	end
	
	def description=(d)
		send("description_#{current_system}=", d) unless d.blank? || d == description_er
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
	
	def related_idea_tag_name
	  return if self.related_idea_tag.blank?
	  related_tag.try :name
	end
	
	def related_tag
	  if self.related_idea_tag.valid_bson_object_id?
	    Tag.find(self.related_idea_tag)
	  else
	    tags.available.send(is_ee? ? :subcurriculums : :themes).first	    
	  end
	end
	
	def four_related_ideas
	  related_tag.ideas.send(current_system).available.where(:_id.ne => self.id).limit(4) rescue []
	end
	
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
			image_url(version)
		else
		  return image.default_url_edu(version) if is_ee? && FileTest.exists?("#{Rails.root}/public/#{image.default_url_edu(version)}")
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
end
