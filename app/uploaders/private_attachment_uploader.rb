# encoding: utf-8

class PrivateAttachmentUploader < CarrierWave::Uploader::Base

  #include CarrierWave::ImageScience

  storage :grid_fs
  ignore_integrity_errors false
  validate_integrity true
  #permissions 0777

  def cache_dir
    "#{Rails.root}/tmp/uploads"
  end

  def extension_white_list
    model.class == Firmware ? %w(exe dmg zip) : %w(jpg jpeg png pdf doc docx rtf txt gif)
  end

  def store_dir
    "#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

end
