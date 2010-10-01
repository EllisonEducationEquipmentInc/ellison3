class Tag
	include EllisonSystem
  include Mongoid::Document
	include Mongoid::Timestamps
	include ActiveModel::Validations
	include ActiveModel::Translation
	
	TYPES = ["artist", "calendar_event", "category", "curriculum", "designer", "exclusive", "machine_compatibility", "material_compatibility", "product_family", "product_line", "special", "subcategory", "subcurriculum", "subtheme", "theme"]
  
  references_many :products, :stored_as => :array, :inverse_of => :tags, :index => true
  
  validates :name, :tag_type, :systems_enabled, :permalink, :presence => true
  validates_format_of :permalink, :with => /^[\w\d-]+$/
  validate :permalink_uniqueness
  
  before_save :inherit_system_specific_attributes
  before_validation :set_permalink
  
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
	
	index :systems_enabled
	index :permalink
	index :tag_type
	index :active
	
	# scopes
	scope :active, :where => { :active => true }
	scope :inactive, :where => { :active => false }
	#scope :available, lambda { |sys = current_system| where(:active => true, :systems_enabled.in => [sys], :"start_date_#{sys}".lte => Time.zone.now, :"end_date_#{sys}".gte => Time.zone.now) }
	ELLISON_SYSTEMS.each do |sys|
		scope sys.to_sym, :where => { :systems_enabled.in => [sys] }  # scope :szuk, :where => { :systems_enabled => "szuk" } #dynaically create a scope for each system. ex.:  Tag.szus => scope for sizzix US tags
	end
	TYPES.each do |type|
	  scope type.pluralize.to_sym, :where => { :tag_type => type }  # scope :calendar_events, :where => { :tag_type => "calendar_event" } #dynaically create a scope for each type. ex.:  Tag.calendar_events => scope for calendar event tags
	end
	
	class << self
		
		def available(sys = current_system)
			active.where(:systems_enabled.in => [sys], :"start_date_#{sys}".lte => Time.zone.now, :"end_date_#{sys}".gte => Time.zone.now)
		end
		
		def find_by_permalink(facet, permalink)
		  active.where(:tag_type => facet.to_s.gsub(Regexp.new("_#{current_system}$"), ""), :permalink => permalink).cache.first
		end
	end
	
	# temporary many-to-many association fix until patch is released
	def my_product_ids=(ids)
	  self.products = Product.where(:_id.in => ids.compact.map {|i| BSON::ObjectId(i)}).map {|p| p}
	end

private 

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