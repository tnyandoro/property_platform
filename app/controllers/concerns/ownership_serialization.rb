module OwnershipSerialization
  include DocumentSerialization

  private

  def ownership_payload(record)
    {
      id: record.id,
      party: {
        id: record.party.id,
        name: record.party.name,
        party_type: record.party.party_type
      },
      ownership_percentage: record.ownership_percentage,
      start_date: record.start_date,
      end_date: record.end_date,
      effective_status: record.effective_status,
      transfer_type: record.transfer_type,
      transfer_value: record.transfer_value,
      valuation_at_transfer: record.valuation_at_transfer,
      currency: record.currency,
      transfer_reference: record.transfer_reference,
      conveyancer: record.conveyancer,
      notes: record.notes,
      verification_status: record.verification_status,
      verified_at: record.verified_at,
      verified_by: record.verified_by && {
        id: record.verified_by.id,
        name: "#{record.verified_by.first_name} #{record.verified_by.last_name}"
      },
      documents: record.documents.map { |document| document_payload(document) }
    }
  end
end
