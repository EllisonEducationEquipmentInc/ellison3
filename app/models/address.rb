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
	
	validates :address_type, :first_name, :last_name, :address1, :city, :zip_code, :phone, :country, :presence => true
	validate :not_verified
	# validates_presence_of :state, :if => Proc.new(&:us?)
	# validates_format_of :zip_code, :with => /^\d{5}(-\d{4})?$/, :if => Proc.new(&:us?)
	# validates_format_of :phone, :with => /^(1-?)?(\([2-9]\d{2}\)|[2-9]\d{2})-?[2-9]\d{2}-?\d{4}$/, :if => Proc.new(&:us?)
	
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
		@fedex = Fedex::Base.new(:auth_key => FEDEX_AUTH_KEY, :security_code => FEDEX_SECURITY_CODE, :account_number => FEDEX_ACCOUNT_NUMBER, :meter_number => FEDEX_METER_NUMBER)
		SystemTimer.timeout_after(50) do
			@fedex.address_validation(:country => country_2_code(self.country), :street => "#{self.address1} #{self.address2}", :city => self.city, :state => self.state, :zip => self.zip_code)
		end
		self.enable_avs_bypass = true if @fedex.result.addressResults.proposedAddressDetails.changes.include?("INSUFFICIENT_DATA") && !@fedex.result.addressResults.proposedAddressDetails.changes.include?("BOX_NUMBER_MATCH")
		if @fedex.result.addressResults.proposedAddressDetails.changes.include?("INSUFFICIENT_DATA") || @fedex.result.addressResults.proposedAddressDetails.changes.include?("BOX_NUMBER_MATCH") 
			self.avs_failed = true
		else
			self.avs_result = @fedex.result.addressResults.proposedAddressDetails.changes
			correct_address(@fedex.result.addressResults.proposedAddressDetails.address)
		end
	end
	
	# accepts a @fedex.result.addressResults.proposedAddressDetails.address as an argument to update corrected shipping address 
  def correct_address(fedex_avs_result)
    raise "Invalid AVS result. Got #{fedex_avs_result.class}. Pass a fedex AVS result" unless fedex_avs_result.class == SOAP::Mapping::Object
    self.address1 = fedex_avs_result.streetLines
    self.address2 = nil
    self.state = fedex_avs_result.stateOrProvinceCode.upcase
    self.zip_code = fedex_avs_result.postalCode
    #self.state = fedex_avs_result.countryCode
    self.city = fedex_avs_result.city
    save(:validate => false)
  end

	def country_2_code(country)
  	Country.where(:name => country).first.try :iso
  end

	def must_be_verified?
		us? && self.address_type == "shipping" && !self.bypass_avs
  end

	def not_verified
		errors.add(:address, "The Shipping address you entered could not be validated. \nPlease enter a valid street name. We can’t deliver to a P.O.Box") if must_be_verified? && self.avs_failed
	end
	
	def set_avs_result
		self.avs_result = "BYPASSED" if self.bypass_avs
	end
end
