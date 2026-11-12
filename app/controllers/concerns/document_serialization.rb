module DocumentSerialization
  private

  def document_payload(document)
    {
      id: document.id,
      title: document.title,
      document_type: document.document_type,
      description: document.description,
      content_type: document.content_type,
      file_size_bytes: document.file_size_bytes,
      url: document.download_url,
      uploaded_by_id: document.uploaded_by_id,
      created_at: document.created_at
    }
  end
end
