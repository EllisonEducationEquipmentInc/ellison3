class LandingPage
  include EllisonSystem
	include ActiveModel::Validations
	include ActiveModel::Translation
	include Mongoid::Document
	include Mongoid::Timestamps
	include Mongoid::Paranoia
	include Mongoid::Associations::EmbeddedCallbacks
	
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
	field :outlet, :type => Boolean, :default => false
	field :quick_search, :type => Boolean, :default => true
	
	key :permalink
	index :active
	index :start_date
	index :end_date
	index :search_query
	index :updated_at
	index :systems_enabled
	
  # before_save :save_image_visual_assets

  embeds_many :visual_assets do
    def current
			@target.select {|asset| asset.available?}.sort {|x,y| x.display_order <=> y.display_order}
    end

		def ordered
			@target.sort {|x,y| x.display_order <=> y.display_order}
		end

		def resort!(ids)
			@target.each {|t| t.display_order = ids.index(t.id.to_s)}
		end
  end
  
  accepts_nested_attributes_for :visual_assets, :allow_destroy => true, :reject_if => proc { |attributes| attributes['name'].blank?}
	validates_associated :visual_assets
	
	validates :name, :permalink, :systems_enabled, :start_date, :end_date, :presence => true
	validates_uniqueness_of :permalink
	validates_format_of :permalink, :with => /^[a-z0-9-]+$/, :message => "Use only alphanumeric characters (all lowercase, no spaces or special characters). Examle: st-patrick-day-sale"
	
	# scopes
	scope :active, :where => { :active => true }
	scope :inactive, :where => { :active => false }

private
  
  def save_image_visual_assets
    visual_assets.select {|e| e.asset_type == 'image'}.each {|asset| asset.valid?}
  end
end