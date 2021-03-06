class DocumentTypeUploadForm < QuestionsForm
  set_attributes_for :intake, :document
  validates :document, file_type_allowed: true

  def initialize(document_type, *args, **kwargs)
    @document_type = document_type
    super(*args, **kwargs)
  end

  def save
    document_file_upload = attributes_for(:intake)[:document]
    if document_file_upload.present?
      @intake.documents.create(
        document_type: @document_type,
        client: @intake.client,
        uploaded_by: @intake.client,
        upload: document_file_upload
      )
    end
  end
end
