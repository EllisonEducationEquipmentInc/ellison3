class Address
	include EllisonSystem
  include Mongoid::Document
	include ActiveModel::Validations
	include ActiveModel::Translation
	
	attr_accessor :enable_avs_bypass
		
	field :address_type, :default => "shipping"
	field :default, :type => Boolean
	field :first_name
	field :last_name
	field :company
	field :address1
	field :address2
	field :city
	field :state
	field :zip_code
	field :country
	field :phone
	field :fax
	field :email
	field :avs_result
	
	embedded_in :user, :inverse_of => :addresses
	embedded_in :order, :inverse_of => :addresses
	embedded_in :quote, :inverse_of => :addresses
	
	validates :address_type, :first_name, :last_name, :address1, :city, :zip_code, :phone, :country, :presence => true
	validate :not_verified
	validates_presence_of :state, :if => Proc.new {|p| p.us?}
	validates_format_of :zip_code, :with => /^\d{5}(-\d{4})?$/, :if => Proc.new {|p| p.us?}
	validates_format_of :phone, :with => /^(1-?)?(\([2-9]\d{2}\)|[2-9]\d{2})-?[2-9]\d{2}-?\d{4}$/, :if => Proc.new {|p| p.us?}
	
	before_validation :validate_address, :if => :must_be_verified?
	before_save :set_avs_result
	
	def initialize(attributes = nil)
		super(attributes)
		self.country ||= "United States" if is_us?
		self.country ||= "United Kingdom" if is_uk?
	end
	
	def enable_avs_bypass
		@enable_avs_bypass ||= false
	end
	
	def bypass_avs
		@bypass_avs ||= false
	end
	
	def bypass_avs=(b)
		@bypass_avs = Boolean.set(b)
	end
		
	def avs_failed
		@avs_failed ||= false
	end
	
	def avs_failed=(avs)
		@avs_failed = avs
	end
	
	def us?
		self.country == "United States"
	end
		
	def validate_address
		self.avs_result = nil
		@fedex = Shippinglogic::FedEx.new(FEDEX_AUTH_KEY, FEDEX_SECURITY_CODE, FEDEX_ACCOUNT_NUMBER, FEDEX_METER_NUMBER, :test => false)
		timeout(50) do
			@fedex.address :streets => "#{self.address1} #{self.address2}", :city => self.city, :state => self.state, :postal_code => self.zip_code, :country => country_2_code(self.country)
		end
		self.enable_avs_bypass = true if @fedex.address.changes.include?("INSUFFICIENT_DATA") && !@fedex.address.changes.include?("BOX_NUMBER_MATCH")
		if @fedex.address.changes.include?("INSUFFICIENT_DATA") || @fedex.address.changes.include?("BOX_NUMBER_MATCH") 
			self.avs_failed = true
		else
			self.avs_result = @fedex.address.changes
			correct_address(@fedex.address.address)
		end
	end
	
  def correct_address(fedex_avs_result)
    self.address1 = fedex_avs_result[:street_lines]
    self.address2 = nil
    self.state = fedex_avs_result[:state_or_province_code]
    self.zip_code = fedex_avs_result[:postal_code]
    self.city = fedex_avs_result[:city]
    save(:validate => false)
  end

	def country_2_code(country)
  	Country.where(:name => country).cache.first.try :iso
  end
  
  def vat_exempt?
    self.address_type == "shipping" && Country.where(:name => self.country).cache.first.try(:vat_exempt)
  end
  
  def gbp_only?
    self.address_type == "billing" && Country.where(:name => self.country).cache.first.try(:gbp)
  end

	def must_be_verified?
		us? && self.address_type == "shipping" && !self.bypass_avs
  end

	def not_verified
		errors.add(:address, "The Shipping address you entered could not be validated. \nPlease enter a valid street name. We can't deliver to a P.O.Box") if must_be_verified? && self.avs_failed
	end
	
	def set_avs_result
		self.avs_result = "BYPASSED" if self.bypass_avs
	end
end
