class Event
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :active, :type => Boolean, :default => true
  field :systems_enabled, :type => Array
  field :event_number
  field :name
  field :uploaded_logo_url
  field :uploaded_image_url
  field :description
  field :keywords
  field :start_date, :type => DateTime
  field :end_date, :type => DateTime
  field :event_start_date, :type => DateTime
  field :event_end_date, :type => DateTime
  field :sponsor
  field :location
  field :address1
	field :address2
	field :city
  field :state
  field :zip_code
  field :country
  
  index :name
  index :systems_enabled
  index :event_number
  index :start_date
  index :end_date
  index :active
  index :event_number
  
  validates :name, :event_number, :description, :systems_enabled, :presence => true

  mount_uploader :image, GenericImageUploader
  mount_uploader :logo, GenericImageUploader

  scope :active, :where => { :active => true }

  def self.available
		active.where(:"start_date".lte => Time.zone.now.change(:sec => 1), :"end_date".gte => Time.zone.now.change(:sec => 1), :systems_enabled.in => [current_system])
	end
	
	def actual_image
    image? ? image_url(:event) : self.uploaded_image_url
  end
  
  def actual_logo
    logo? ? logo_url(:logo) : self.uploaded_logo_url
  end
  
  def destroy
    update_attribute :active, false
  end
end
