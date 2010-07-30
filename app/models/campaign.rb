class Campaign
	include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	include Mongoid::Versioning
	include Mongoid::Timestamps
	include Mongoid::Paranoia
	
	
end