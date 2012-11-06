class Store
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  include Geokit::Geocoders

  US_STATES = ["AA", "AE", "AP", "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "DC", "FL", "GA", "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD", "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ", "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC", "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY"]
  AGENT_TYPES = ["Distributor", "Sales Representative", "Authorized Reseller"]
  AUTHORIZED_RESELLER_TYPES = ["Catalog sales only", "Web sales only", "Brick and Mortar Store", "Combination"]
  PRODUCT_LINES = %w(Sizzix eclips AllStar Prestige Quilting RollModel)
  BRANDS = %w(sizzix ellison)
  EXCELLENCE_LEVELS = ["Executive", "Preferred", "Elite"]

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

  field :representative_serving_states, :type => Array
  field :representative_serving_states_locations, :type => Hash, :default => {}
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

  validates_presence_of :name, :brands, :agent_type, :systems_enabled
  validates_presence_of :address1, :city, :country, :if => :physical_store?
  validates_presence_of :website, :if => :webstore?
  validates_inclusion_of :agent_type, :in => AGENT_TYPES
  #validates_inclusion_of :brands, :in => BRANDS
  #validates_inclusion_of :product_line, :in => PRODUCT_LINES

  validate :representative_states_selected?
  validate :get_geo_location, :if => :physical_store?
  before_save :validate_sales_representative_states
  before_save :set_serving_states_locations, :if => :physical_store?

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

  def self.catalog_companies
    where(catalog_company: true)
  end

  def self.distinct_states country='United States'
    sales_representative_states = active.physical_stores.where(:country => country, :agent_type => 'Sales Representative').distinct(:representative_serving_states)
    states = active.physical_stores.where(:country => country).excludes(:agent_type => 'Sales Representative').distinct(:state)
    states.concat(sales_representative_states).uniq.delete_if{ |state| state.blank? }.sort
  end

  def self.all_by_state state
    all_by_country('United States').any_of({ :state => state }, { :representative_serving_states => state })
  end

  def self.all_by_country country
    active.physical_stores.where(:country => country).order_by(:name => :asc)
  end

  def self.all_by_locations_for country, code_location, radius
    all_by_country(country).where(:location.within => { "$center" => [ [code_location.lat, code_location.lng], ((radius.to_i * 20)/(3963.192*0.3141592653))] })
  end

  def self.stores_for name, country, state, zip_code, zip_geo, radius
    if name.present?
      all_by_country(country).where(:name => /#{name}/i)
    elsif state.present?
      all_by_state(state)
    elsif zip_code.present?
      if country == "United States" && zip_code =~ /^\d{5,}/
        all_by_locations_for(country, zip_geo, radius)
      elsif country == "United Kingdom"
        all_by_locations_for(country, zip_geo, radius)
      end
    else
      all_by_country(country)
    end.to_a
  end

  private

  def valid_serving_states_representative?
    country == 'United States' && agent_type == 'Sales Representative'
  end

  def serving_states?
    representative_serving_states.present?
  end

  def validate_sales_representative_states
    if serving_states? && !valid_serving_states_representative?
      errors.add(:base, "Admin can't be a serving representative")
      false
    end
  end

  def representative_states_selected?
    if agent_type == 'Sales Representative' and serving_states?
      representative_serving_states.each do |state|
        unless US_STATES.include? state
          errors.add(:representative_serving_states, "Invalid US State: #{state}.")
          return false
        end
      end
    end
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

  def set_serving_states_locations
    if valid_serving_states_representative? && representative_serving_states.present?
      states_hash = representative_serving_states.each_with_object({ }) do |state, hash|
        position = MultiGeocoder.geocode(state)
        hash[ state ] = [ position.lat, position.lng ] if position.success
      end

      self.representative_serving_states_locations = states_hash if states_hash.present?
    end
  end
end
