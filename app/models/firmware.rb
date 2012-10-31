class Firmware
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name
  field :active, :type => Boolean, :default => true
  field :display_order, :type => Integer, :default => 100

  field :created_by
  field :updated_by

  scope :active, :where => { :active => true }

  validates_presence_of :name, :file

  mount_uploader :file, PrivateAttachmentUploader

  def destroy
    update_attribute :active, false
  end
end
