module OldData
  class Customer < ActiveRecord::Base

    validates_presence_of :first_name, :last_name, :email, :address, :city, :zip_code, :country, :phone, :message => "of Shipping address can't be blank"
    validates_presence_of :company, :message => "of Shipping Address can't be blank ", :if => Proc.new {|p| p.is_er?}
    validates_presence_of :state, :if => Proc.new{|p| p.country == "United States"}
    validates_length_of :first_name, :in => 2..255
    validates_length_of :last_name, :in => 2..255
    validates_length_of :address, :in => 2..255
    validates_length_of :city, :in => 2..255 
    validates_length_of :phone, :is => 10, :if => Proc.new{|p| p.country == "United States"}
    validates_length_of :phone, :in => 5..20, :if => Proc.new{|p| p.country != "United States"}
    validates_length_of :state, :in => 2..255, :if => Proc.new{|p| p.country == "United States"}
    validates_length_of :country, :in => 2..255
    validates_length_of :zip_code, :in => 3..10
    validates_numericality_of :phone , :if => Proc.new{|p| p.country == "United States"}
    #validates_format_of :zip_code, :with => /(?:[A-Z]{1,2}\d(?:\d|[A-Z])? \d[A-Z]{2})$/i,  :message => "is not a British Standard (BS 7666) Postal Code", :if => proc { |obj| obj.country == "United Kingdom" }
                                      #[A-Z]{1,2}[0-9R][0-9A-Z]? [0-9][A-Z]{2}
    attr_accessor :comments

    serialize :avs_result

    belongs_to :user

    # accepts a @fedex.result.addressResults.proposedAddressDetails.address as an argument to update corrected shipping address 
    def correct_address(fedex_avs_result)
      raise "Invalid AVS result. Got #{fedex_avs_result.class}. Pass a fedex AVS result" unless fedex_avs_result.class == SOAP::Mapping::Object
      self.address = fedex_avs_result.streetLines
      self.address2 = nil
      self.state = fedex_avs_result.stateOrProvinceCode.upcase
      self.zip_code = fedex_avs_result.postalCode
      #self.state = fedex_avs_result.countryCode
      self.city = fedex_avs_result.city
      save(false)
    end

    def avs_message
      return if avs_result.blank?
      case 
      when avs_result.include?("NO_CHANGES") || avs_result.include?("NORMALIZED")
        "Shipping address successfully verified"
      when avs_result.include?("MODIFIED_TO_ACHIEVE_MATCH")
        "Shipping address has been modified by the address verification service. " +  avs_result.to_a.reject {|r| r ==  "MODIFIED_TO_ACHIEVE_MATCH"}.map {|c| c.downcase.humanize}.join(", ")
      else
        "Shipping address verification result: " + avs_result.to_a.map {|c| c.downcase.humanize}.join(", ")
      end
    end

    def us?
      read_attribute(:country) == "United States"
    end

    # custom validation
    def validate_on_update
      if read_attribute('country') == "United States"
        if !Zipcode.valid_address?(read_attribute('city'),
                                   read_attribute('state'),
                                   read_attribute('zip_code')[/^\d{5}/])
          # we'll only report on one of the fields to reduce confusion
          #errors.add(:city, "- city/state/zip combination invalid") 
        end
      end
    end

    def validate
      if country == "United Kingdom"
        errors.add(:post_code, "is not a British Standard (BS 7666) Post Code") unless zip_code =~ /(?:[A-Z]{1,2}\d(?:\d|[A-Z])? \d[A-Z]{2})$/i
      end
    end

  end
  
end