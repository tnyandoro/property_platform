class TenantInvitationMailer < ApplicationMailer
  def invitation(tenant_invitation, raw_token)
    @invitation = tenant_invitation
    frontend_url = ENV.fetch("FRONTEND_URL", "http://localhost:5173").delete_suffix("/")
    @activation_url = "#{frontend_url}/accept-tenant-invitation?token=#{CGI.escape(raw_token)}"

    mail(
      to: @invitation.target_email,
      subject: "You're invited to access your property tenancy on Estate360"
    )
  end
end
