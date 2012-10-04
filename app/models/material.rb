class Material
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps

  field :active, :type => Boolean, :default => true
  field :name
  field :download_only, :type => Boolean, :default => false
  field :description
  field :label_code

  mount_uploader :image, GenericImageUploader
  mount_uploader :document, PrivateAttachmentUploader

  #references_many :material_orders, :validate => false, :index => true

  validates :name, :label_code, :presence => true
  validates_presence_of :document, :if => Proc.new {|obj| obj.download_only}

  index :name
  index :label_code

  scope :active, :where => { :active => true }

  def destroy
    update_attribute :active, false
  end
end
