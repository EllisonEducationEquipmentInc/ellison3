module Shippinglogic
  class FedEx
	
		def address(attributes = {})
		  @address ||= Address.new(self, attributes)
		end
		
		class Address < Service
			
			class Service; attr_accessor :score, :changes, :delivery_point_validation, :address, :removed_non_address_data; end
			
			VERSION = { :major => 2, :intermediate => 0, :minor => 0}
			
			attribute :name,              :string
      attribute :title,             :string
      attribute :company_name,      :string
      attribute :phone_number,      :string
      attribute :email,             :string
      attribute :streets,           :string
      attribute :city,              :string
      attribute :state,             :string
      attribute :postal_code,       :string
      attribute :country,           :string,      :modifier => :country_code

		  private
        def target
          @target ||= parse_response(request(build_request))
        end
        
        def build_request
          b = builder
          xml = b.AddressValidationRequest(:xmlns => "http://fedex.com/ws/addressvalidation/v#{VERSION[:major]}") do
            build_authentication(b)
            build_version(b, "aval", VERSION[:major], VERSION[:intermediate], VERSION[:minor])
            
						b.RequestTimestamp Time.now.strftime("%Y-%m-%dT%H:%M:%S")
						b.Options do
							b.VerifyAddresses true
		          #b.CompanyNameAccuracy "LOOSE"
							#b.StreetAccuracy "LOOSE"
							#b.DirectionalAccuracy "LOOSE"
							#b.MaximumNumberOfMatches  10
						end
		        b.AddressesToValidate do
		          b.CompanyName(company_name) if company_name
		          b.Address do
		            b.StreetLines streets
		            b.City city
		            b.StateOrProvinceCode state
		            b.PostalCode postal_code
		            b.CountryCode country
		          end  
		        end
          end
        end

				def parse_response(response)
					return [] unless response[:address_results] && response[:address_results][:proposed_address_details]
					service = Service.new
					response[:address_results][:proposed_address_details].each do |key, value|
						service.send("#{key}=",value)
					end
					service
				end
		end
	end
end