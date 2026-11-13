class MaintenancePaymentStatusUpdater
  class InvalidTransition < StandardError; end

  def self.call(payment:)
    invoice = payment.invoice
    raise ActiveRecord::RecordNotFound unless invoice.is_a?(MaintenanceInvoice)

    invoice.with_lock do
      payment.lock!
      raise InvalidTransition, "Only a pending payment can be marked paid." unless payment.status == "pending"

      payment.update!(status: "paid")
    end
    payment
  end
end
