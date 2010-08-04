class SystemSetting
	include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	include Mongoid::Versioning
  include Mongoid::Timestamps
	include Mongoid::Paranoia
	
	field :key
	field :value
	
	index :key, :unique => true
	
	class << self
		def value_at(key)
			first(:conditions => { :key => key}).try :value
		end
		
	end
end