# encoding: utf-8

class ImageUploader < CarrierWave::Uploader::Base
	
  # Include RMagick or ImageScience support
  #     include CarrierWave::RMagick
	#require 'carrierwave/processing/image_science'
  include CarrierWave::ImageScience

	# include CarrierWave::Compatibility::Paperclip 
	# 
	# 
	# def paperclip_path 
	#   #":rails_root/public/photos/:style/:basename.:extension" 
	# 	"#{RAILS_ROOT}/public/images/:style/:basename.:extension"
	# end 
	#   
	# 
	#   # Choose what kind of storage to use for this uploader
	# enable_processing = true
	#   storage :file
	#   permissions 0777 
	#  #     storage :s3
	# 
	#   # Override the directory where uploaded files will be stored
	#   # This is a sensible default for uploaders that are meant to be mounted:
	#   def store_dir
	#     #"uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.item_num}"
	# 	"#{RAILS_ROOT}/public/images/#{model.class.to_s.underscore}/#{mounted_as}/#{model.item_num}"
	#   end
	# 
	# def cache_dir
	#   "#{RAILS_ROOT}/tmp/uploads"
	# end
  # 
  # # Provide a default URL as a default if there hasn't been a file uploaded
  #     def default_url
  #       #"/images/fallback/" + [version_name, "default.png"].compact.join('_')
  # 				version_name = "medium" if version_name.blank?
  #       "/images/products/#{version_name}/#{model.item_num}.jpg"
  #     end
  # 
  # Process files as they are uploaded.
      process :resize_to_fill => [300, 300]
  #
  #     def scale(width, height)
  #       # do something
  #     end
  
  # Create different versions of your uploaded files
      version :small do
        process :resize_to_fill => [65, 65]
      end
  
  			version :medium do
        process :resize_to_fill => [125, 125]
      end
  # 
  # # Add a white list of extensions which are allowed to be uploaded,
  # # for images you might use something like this:
  #     def extension_white_list
  #       %w(jpg jpeg gif png)
  #     end
  # 
  # # Override the filename of the uploaded files
  # #     def filename
  # #       "something.jpg" if original_filename
  # #     end

end
