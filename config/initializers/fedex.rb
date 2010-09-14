# === extension of fedex plugin to handle address_validation service
#
#   fedex = Fedex::Base.new(options)
#   fedex.address_validation(:country => "US", :street => "123 main st", :city => "costa mesa", :state => "CA", :zip => "92629")
# 
# if verification is successful, returns the corrected address in a [streetLines, city, stateOrProvinceCode, postalCode, countryCode] array, otherwise returns the reasons why it failed
# 
# to access the AV result:
#
#   fedex.result
#
module Fedex #:nodoc:
  class Base
    WSDL_PATHS.merge! :address_validation => 'wsdl/AddressValidationService_v2.wsdl'
    REQUIRED_OPTIONS.merge! :address_validation => [:street, :city, :state, :zip]
    
    AV_WS_VERSION = { :Major => 2, :Intermediate => 0, :Minor => 0, :ServiceId => 'aval' }
    
    attr_accessor :result, :corrected_address
    
    def address_validation(options = {})
      check_required_options(:address_validation, options)
      
      driver = create_driver(:address_validation)
      
      @result = driver.addressValidation(av_common_options.merge(
        :RequestTimestamp => Time.zone.now.strftime("%Y-%m-%dT%H:%M:%S"),
        :AddressesToValidate => [
          :CompanyName => options[:company],
          :Address => {
            :StreetLines => options[:street],
            :City => options[:city],
            :StateOrProvinceCode => options[:state],
            :PostalCode => options[:zip],
            :CountryCode => options[:country] || "US",
          }  
        ],
        :Options => {:VerifyAddresses => 1
          #, :CompanyNameAccuracy => "LOOSE", :StreetAccuracy => "LOOSE", :DirectionalAccuracy => "LOOSE", :MaximumNumberOfMatches => 10
          }
      ))
      
      
      msg = error_msg(result, true)
      successful = successful?(@result)
      
      if successful && msg !~ /There are no valid services available/
        if @result.addressResults.proposedAddressDetails.changes.include?("INSUFFICIENT_DATA")
          @result.addressResults.proposedAddressDetails.changes.to_a.map {|c| c.downcase.humanize}.join(", ") 
        else
          [@result.addressResults.proposedAddressDetails.address.streetLines, @result.addressResults.proposedAddressDetails.address.city, @result.addressResults.proposedAddressDetails.address.stateOrProvinceCode, @result.addressResults.proposedAddressDetails.address.postalCode, @result.addressResults.proposedAddressDetails.address.countryCode]
        end 
      else
        raise FedexError.new("Unable to get Address Verification from Fedex: #{msg}")
      end
    end
            
  private

    def av_common_options
      h = common_options
      h.delete(:Version)
      h.merge(:Version => AV_WS_VERSION)
    end
  end

end