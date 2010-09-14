class Country
	include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	include Mongoid::Timestamps
	
	field :iso_name
	field :iso
	field :name
	field :iso3
	field :numcode

	validates_presence_of :iso_name, :iso, :name, :iso3, :numcode
	validates_uniqueness_of :iso_name, :iso, :name, :iso3
end