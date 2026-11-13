module DocumentSerialization
  private

  def document_payload(document, blob: nil)
    blob ||= ActiveStorage::Blob.find_by(key: document.storage_key)

    {
      id: document.id,
      title: document.title,
      document_type: document.document_type,
      description: document.description,
      content_type: document.content_type,
      file_size_bytes: document.file_size_bytes,
      url: blob&.url(expires_in: 1.hour),
      uploaded_by_id: document.uploaded_by_id,
      created_at: document.created_at
    }
  end
end
