require 'attachment_fu'
require 'file_system_backend'
require 'image_science_processor'

module OldData
  class Attachment < ActiveRecord::Base
    ActiveRecord::Base.send(:extend, Technoweenie::AttachmentFu::ActMethods)

    has_attachment :content_type => ['application/pdf', 'application/msword', :image], :storage => :file_system, :max_size => 4.megabytes, :path_prefix => "attachments", :processor => "ImageScience"
    validates_presence_of :filename
    validates_as_attachment
  end
end