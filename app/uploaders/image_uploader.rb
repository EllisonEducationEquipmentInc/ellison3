# encoding: utf-8

class ImageUploader < CarrierWave::Uploader::Base
	
  # Include RMagick or ImageScience support
  #     include CarrierWave::RMagick
	#require 'carrierwave/processing/image_science'
  include CarrierWave::ImageScience


	# Choose what kind of storage to use for this uploader (comment out this block if you want to store files in mongodb gridfs)
	# ================ file storage block starts ===============
	storage :file
	permissions 0777 

  # Override the directory where uploaded files will be stored
  # This is a sensible default for uploaders that are meant to be mounted:
  def store_dir
    #"uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.item_num}"
		"#{Rails.root}/public/images/#{model.class.to_s.pluralize.underscore}/#{version_name}"
  end
	# 
	def cache_dir
	  "#{Rails.root}/tmp/uploads"
	end
	# ================ file storage block ends ================
	
	
	# Override the filename of the uploaded files
  def filename
    "#{model.item_num}.#{file.extension}" if original_filename && file && file.try(:extension)
  end

  # Provide a default URL as a default if there hasn't been a file uploaded
  def default_url(version_name = "medium")
    #"/images/fallback/" + [version_name, "default.png"].compact.join('_')
    "/images/products/#{version_name}/#{model.item_num}.jpg"
  end

  # Process files as they are uploaded.
  process :resize_to_fill => [800, 800]
  
  # Create different versions of your uploaded files
  version :large do
    process :resize_to_fill => [300, 300]
  end

  version :small do
    process :resize_to_fill => [65, 65]
  end

	version :medium do
    process :resize_to_fill => [125, 125]
  end

  # Add a white list of extensions which are allowed to be uploaded,
  # for images you might use something like this:
  def extension_white_list
    %w(jpg jpeg gif png)
  end

end
