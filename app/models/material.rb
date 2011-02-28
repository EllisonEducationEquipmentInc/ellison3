class Material
  include EllisonSystem
  include Mongoid::Document
  include Mongoid::Timestamps
	
	field :active, :type => Boolean, :default => true
	field :name
	field :download_only, :type => Boolean, :default => false
  field :description

  mount_uploader :image, GenericImageUploader
  mount_uploader :document, PrivateAttachmentUploader
	
	#references_many :material_orders, :validate => false, :index => true
	
	validates :name, :presence => true
  validates_presence_of :document, :if => Proc.new {|obj| obj.download_only}
  
  field :index
  
  scope :active, :where => { :active => true }
  
  def destroy
    update_attribute :active, false
  end
end
