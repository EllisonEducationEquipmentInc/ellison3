require 'carrierwave/orm/mongoid'

class Image
	include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	
	embedded_in :product, :inverse_of => :images
	
	mount_uploader :image, GenericImageUploader	
end