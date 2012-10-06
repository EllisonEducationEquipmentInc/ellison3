class Store
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  include Geokit::Geocoders

  AGENT_TYPES = ["Distributor", "Sales Representative", "Authorized Reseller"]
  AUTHORIZED_RESELLER_TYPES = ["Catalog sales only", "Web sales only", "Brick and Mortar Store", "Combination"]
  PRODUCT_LINES = %w(Sizzix eclips AllStar Prestige RollModel)
  BRANDS = %w(sizzix ellison)
  EXCELLENCE_LEVELS = ["Executive", "Preferred", "Elite", "A Cut Above"]

  field :store_number
  field :active, :type => Boolean, :default => true
  field :name
  field :logo_url
  field :webstore, :type => Boolean, :default => false
  field :physical_store, :type => Boolean, :default => false
  field :catalog_company, :type => Boolean, :default => false
  field :brands, :type => Array
  field :product_line, :type => Array, :default => []
  field :agent_type
  field :authorized_reseller_type
  field :excellence_level
  field :has_ellison_design_centers, :type => Boolean, :default => false
  field :location, :type => Array
  field :address1
  field :address2
  field :city
  field :state
  field :zip_code
  field :country
  field :contact_person
  field :phone
  field :fax
  field :email
  field :website
  field :keyword
  field :internal_comments
  field :systems_enabled, :type => Array

  field :created_by
  field :updated_by

  index :country
  index :active
  index :physical_store
  index :webstore
  index [[ :location, Mongo::GEO2D ], [:brands, Mongo::ASCENDING], [:physical_store, Mongo::ASCENDING], [:active, Mongo::ASCENDING] ], :min => -300, :max => 300
  index :brands
  index :agent_type
  index :name

  mount_uploader :image, GenericImageUploader

  validates_presence_of :name, :brands, :agent_type
  validates_presence_of :address1, :city, :country, :if => Proc.new {|obj| obj.physical_store}
  validates_presence_of :website, :if => Proc.new {|obj| obj.webstore}
  validates_inclusion_of :agent_type, :in => AGENT_TYPES
  #validates_inclusion_of :brands, :in => BRANDS
  #validates_inclusion_of :product_line, :in => PRODUCT_LINES

  before_save :get_geo_location, :if => Proc.new {|obj| obj.physical_store}

  scope :physical_stores, :where => { :physical_store => true }
  scope :webstores, :where => { :webstore => true }
  scope :distributors, :where => { :agent_type => "Distributor" }

  def logo
    image? ? image_url(:logo) : self.logo_url
  end

  def destroy
    update_attribute :active, false
  end

  def self.active
    where(active: true, :systems_enabled.in => [ current_system ])
  end

  def self.online_retailers
    active.any_of({ :webstore => true }, { :catalog_company => true }).order_by(:country => :asc, :name => :asc)
  end

  def self.distinct_countries
    active.physical_stores.distinct(:country).sort { |x,y| x <=> y }
  end

  private  

  def representative_serving_states
  end

  def get_geo_location
    if location.blank? || address1_changed? || address2_changed? || city_changed? || state_changed? || zip_code_changed?
      Rails.logger.info "GEocoding #{self.address1} #{self.address2} #{self.city} #{self.state} #{self.zip_code} #{self.country}"
      res = MultiGeocoder.geocode "#{self.address1} #{self.address2} #{self.city} #{self.state} #{self.zip_code} #{self.country}"
      if res.success
        self.location = [res.lat, res.lng]
      else
        errors.add(:location, "Invalid address, could not be Geocoded.")
        return false
      end
    end
  end
end
