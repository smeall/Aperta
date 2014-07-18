class LogoUploader < CarrierWave::Uploader::Base
  include CarrierWave::MiniMagick

  storage Rails.application.config.carrierwave_storage

  def store_dir
    "uploads/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def default_url
    "/images/no-journal-image.gif"
  end

  version :thumbnail do
    process resize_to_limit: [126, 36]

    def full_filename(orig_file)
      "#{version_name}_#{orig_file}"
    end
  end

end
