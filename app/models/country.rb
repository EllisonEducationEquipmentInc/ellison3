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
	field :vat_exempt, :type => Boolean, :default => false
	field :gbp, :type => Boolean, :default => false
	
	index :name

	validates_presence_of :iso_name, :iso, :name, :iso3, :numcode
	validates_uniqueness_of :iso_name, :iso, :name, :iso3
	
end