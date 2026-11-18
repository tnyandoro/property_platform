Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "https://property-platform.vercel.app"

    resource "*",
      headers: %w[Authorization Content-Type Accept Origin],
      methods: %i[get post put patch delete options head],
      max_age: 600
  end
end
