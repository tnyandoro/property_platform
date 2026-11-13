module LeaseSerialization
  private

  def lease_payload(lease)
    {
      id: lease.id,
      unit_id: lease.unit_id,
      tenant_id: lease.tenant_id,
      tenant_name: lease.tenant&.name,
      status: lease.status,
      lease_type: lease.lease_type,
      start_date: lease.start_date,
      end_date: lease.end_date,
      created_at: lease.created_at,
      monthly_rent: lease.monthly_rent,
      rent_currency: lease.rent_currency,
      deposit_amount: lease.deposit_amount,
      pdf_filename: lease.lease_pdf.attached? ? lease.lease_pdf.filename.to_s : nil,
      pdf_url: lease.lease_pdf.attached? ? lease.lease_pdf.blob.url(expires_in: 1.hour) : nil
    }
  end
end
