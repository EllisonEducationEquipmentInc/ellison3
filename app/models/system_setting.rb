class SystemSetting
	include EllisonSystem
	include Mongoid::Document
	include Mongoid::Versioning
  include Mongoid::Timestamps
	include Mongoid::Paranoia
		
	validates :key, :value, :presence => true
	
	field :key
	field :value
	
	index :key, :unique => true
	
	class << self
		def value_at(key)
			first(:conditions => { :key => key}).try :value
		end
		
		def update(key, value)
			first(:conditions => { :key => key}).try :update_attributes, :value => value
		end
	end
end