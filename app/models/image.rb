require 'carrierwave/orm/mongoid'

class Image
  include EllisonSystem
  include Mongoid::Document

  field :caption
  field :details

  embedded_in :product, :inverse_of => :images
  embedded_in :idea, :inverse_of => :images
  embedded_in :tab, :inverse_of => :images

  mount_uploader :image, GenericImageUploader


  def _destroy
    false
  end
end
