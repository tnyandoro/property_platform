Cloudinary.config do |config|
  config.cloud_name = ENV["CLOUDINARY_CLOUD_NAME"] || begin
    Rails.application.credentials.dig(:cloudinary, :cloud_name)
  rescue StandardError
    nil
  end
  config.api_key    = ENV["CLOUDINARY_API_KEY"] || begin
    Rails.application.credentials.dig(:cloudinary, :api_key)
  rescue StandardError
    nil
  end
  config.api_secret = ENV["CLOUDINARY_API_SECRET"] || begin
    Rails.application.credentials.dig(:cloudinary, :api_secret)
  rescue StandardError
    nil
  end
  config.secure = true
end
