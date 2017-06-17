module PaperConverters
  # PDF Converter used to convert added aperta generated PDF files
  class AutoGeneratedPdfToPdfConverter < PdfWithAttachmentsPaperConverter
    def output_filename
      "aperta-generated-PDF.pdf"
    end
  end
end
