class LandingPage
  include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Paranoia
	
	field :name
	field :permalink
	field :systems_enabled, :type => Array
	field :short_desc
  field :content
  field :products, :type => Array
	field :ideas, :type => Array
	field :active, :type => Boolean, :default => true
	field :start_date, :type => DateTime
	field :end_date, :type => DateTime
	field :search_query
	
	key :permalink
	index :active
	index :start_date
	index :end_date
	index :search_query
	index :updated_at
	
	validates :name, :permalink, :systems_enabled, :start_date, :end_date, :presence => true
	validates_uniqueness_of :permalink
	validates_format_of :permalink, :with => /^[a-z0-9-]+$/, :message => "Use only alphanumeric characters (all lowercase, no spaces or special characters). Examle: st-patrick-day-sale"
	
	# scopes
	scope :active, :where => { :active => true }
	scope :inactive, :where => { :active => false }
end