class Address
  include EllisonSystem
  include Mongoid::Document

  attr_accessor :enable_avs_bypas, :allow_po_box

  attr_protected :allow_po_box

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
  field :job_title

  embedded_in :user, :inverse_of => :addresses
  embedded_in :order, :inverse_of => :address
  embedded_in :quote, :inverse_of => :address

  validates :address_type, :first_name, :last_name, :address1, :city, :zip_code, :phone, :country, :presence => true
  validate :not_verified
  validates_presence_of :state, :if => Proc.new {|p| p.us?}
  validates_presence_of :company, :if => Proc.new {|p| p.is_er?}
  validates_format_of :zip_code, :with => /^\d{5}(-\d{4})?$/, :if => Proc.new {|p| p.us?}
  validates_format_of :phone, :with => /^(1(-|\.)?)?(\([2-9]\d{2}\)|[2-9]\d{2})(-|\.)?[2-9]\d{2}(-|\.)?\d{4}$/, :if => Proc.new {|p| p.us?}
  validates_format_of :email, :with => /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i

  after_validation :validate_address, :if => :must_be_verified?
  before_save :set_avs_result

  def initialize(attributes = nil)
    super(attributes)
    self.allow_po_box = false if self.allow_po_box.nil?
    self.country ||= "United States" if is_us?
    self.country ||= "United Kingdom" if is_uk?
  end

  def enable_avs_bypass
    @enable_avs_bypass ||= false
  end

  def enable_avs_bypass=(v)
    @enable_avs_bypass = Boolean.set(v)
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

  def with_state?
    us? || self.country == "Canada"
  end

  def apo?
    us? && %w(AA AE AP).include?(self.state.try(:upcase))
  end

  def validate_address
    self.avs_result = nil
    @fedex = Fedex::Shipment.new(key: FEDEX_AUTH_KEY, password: FEDEX_SECURITY_CODE, account_number: FEDEX_ACCOUNT_NUMBER, meter:  FEDEX_METER_NUMBER, mode: 'production')
    timeout(50) do
      Rails.logger.info "FEDEX validating address."
      @address_result = @fedex.validate_address address: {street: "#{self.address1} #{self.address2}", city: self.city, state: self.state, postal_code: self.zip_code, country: country_2_code(self.country)}
    end
    self.enable_avs_bypass = true if (@address_result.score < 20 || @address_result.changes.include?("INSUFFICIENT_DATA")) && !@address_result.changes.include?("BOX_NUMBER_MATCH")
    if @address_result.score < 20 || @address_result.changes.include?("INSUFFICIENT_DATA") || @address_result.changes.include?("BOX_NUMBER_MATCH") && !self.allow_po_box
      self.avs_failed = true
    else
      self.avs_result = @address_result.changes.is_a?(Array) ? @address_result.changes * ', ' : @address_result.changes
      correct_address(@address_result)
    end
  rescue Timeout::Error => e
    Rails.logger.error e.message
    self.bypass_avs = true
  end

  def correct_address(fedex_avs_result)
    self.address1 = fedex_avs_result.street_lines
    self.address2 = nil
    self.state = fedex_avs_result.province_code
    self.zip_code = fedex_avs_result.postal_code
    self.city = fedex_avs_result.city
    save(:validate => false)
  end

  def country_2_code(country)
    Country.name_2_code(country)
  end

  def vat_exempt?
    self.address_type == "shipping" && Country.where(:name => self.country).cache.first.try(:vat_exempt)
  end

  def gbp_only?
    self.address_type == "billing" && Country.where(:name => self.country).cache.first.try(:gbp)
  end

  def must_be_verified?
    errors.blank? && us? && self.address_type == "shipping" && !%w(AE AP AA HI AK).include?(self.state) && !self.bypass_avs && (self.changed? || self.new_record?)
  end

  def not_verified
    errors.add(:address, "The shipping address you entered could not be validated. \nPlease enter a valid street name. #{self.allow_po_box ? '' : 'We cannot deliver to a P.O. Box.'}") if must_be_verified? && self.avs_failed
  end

  def set_avs_result
    self.avs_result = "BYPASSED" if self.bypass_avs
  end


end
