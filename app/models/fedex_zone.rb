class FedexZone
  include EllisonSystem
  include Mongoid::Document
	
	ZONES = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 17, "APO"] 
	
	field :zip_start, :type => Integer
	field :zip_end, :type => Integer
	field :zone, :type => Integer
	field :express_zone, :type => Integer
	
	index :zip_start
	index :zip_end
	
	validates :zip_start, :zip_end, :zone, :presence => true
	validates_numericality_of :zip_start, :zip_end, :zone, :only_integer => true
	
	class << self
	  def find_by_zip(zip)
	    Rails.cache.fetch("fedex_zone_#{zip}", :expires_in => 1.days) do
	      where({:zip_start.lte => zip.to_i, :zip_end.gte => zip.to_i}).first
	    end
	  end
	  
	  def find_by_address(address)
	    address.apo? ? "APO" : find_by_zip(address.zip_code)
	  end
	  
	  def get_zone_by_address(address)
	    z = find_by_address(address)
	    z.respond_to?(:zone) ? z.zone : z
	  end
	end
end
