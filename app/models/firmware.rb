class Firmware
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
  
  field :name
  field :active, :type => Boolean, :default => true
  
  field :created_by
	field :updated_by
  
  scope :active, :where => { :active => true }
  
  validates_presence_of :name, :file
  
  mount_uploader :file, PrivateAttachmentUploader
  
  def destroy
    update_attribute :active, false
  end
end
