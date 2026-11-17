class ApplicationMailer < ActionMailer::Base
  default from: -> { ENV.fetch("MAILER_FROM", "Estate360 <estate360@saraphim.co.za>") }
  layout "mailer"
end
