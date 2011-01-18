class Store
  include EllisonSystem
	include Mongoid::Document
	include Mongoid::Timestamps
	include Geokit::Geocoders
	
	AGENT_TYPES = ["Distributor", "Sales Representative", "Authorized Reseller"]
	AUTHORIZED_RESELLER_TYPES = ["Catalog sales only", "Web sales only", "Brick and Mortar Store", "Combination"]
	PRODUCT_LINES = %w(AllStar Prestige RollModel)
	BRANDS = %w(sizzix ellison)
	
	field :store_number
  field :active, :type => Boolean, :default => true
  field :name
  field :logo_url
  field :webstore, :type => Boolean, :default => false
  field :physical_store, :type => Boolean, :default => false
  field :brands, :type => Array
  field :product_line, :type => Array
  field :agent_type
  field :authorized_reseller_type
  field :excellence_level
  field :has_ellison_desig_centers, :type => Boolean, :default => false
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
  
  index :country
  index :active
  index :physical_store
  index :webstore
  index [[ :location, Mongo::GEO2D ]], :min => -300, :max => 300
  index :brands
  
  mount_uploader :image, GenericImageUploader
  
  validates_presence_of :name, :brands, :address1, :city, :country
  
  before_save :get_geo_location, :if => Proc.new {|obj| obj.physical_store}
  
  scope :active, :where => { :active => true }
  scope :physical_stores, :where => { :physical_store => true }
  scope :webstores, :where => { :webstore => true }
  
  def logo
    image? ? image_url(:logo) : self.logo_url
  end
  
  #Red=AllStar, Green=Prestige, Purple=RollModel

private  

  def get_geo_location
    if location.blank? || address1_changed? || address2_changed? || city_changed? || state_changed? || zip_code_changed?
      res = MultiGeocoder.geocode "#{self.address1} #{self.address2} #{self.city} #{self.state} #{self.zip_code} #{self.country}"
      self.location = [res.lat, res.lng] 
    end
  end
end
