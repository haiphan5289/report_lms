//
//  PDFPreviewView.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/4/26.
//

import SwiftUI
import PDFKit
import OSLog

/// SwiftUI wrapper for PDFView to preview PDF documents
struct PDFPreviewView: View {
    let pdfData: Data
    let fileName: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var activeAlert: AlertType?
    @State private var savedURL: URL?
    @State private var errorMessage: String?
    
    private let logger = Logger(subsystem: "com.reportlms.pdf", category: "preview")
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // PDF Viewer
                PDFKitView(data: pdfData)
                
                // Action Buttons
                HStack(spacing: 16) {
                    // Save to Files button
                    Button(action: saveToFiles) {
                        Label("Lưu vào Files", systemImage: "folder.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel("Lưu báo cáo PDF vào Files")
                    .accessibilityHint("Lưu file PDF vào thư mục Documents trên thiết bị")
                    
                    // Share button
                    Button(action: { showShareSheet = true }) {
                        Label("Chia sẻ", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .accessibilityLabel("Chia sẻ báo cáo PDF")
                    .accessibilityHint("Gửi PDF qua AirDrop, Messages, hoặc các ứng dụng khác")
                }
                .padding()
            }
            .navigationTitle("Preview PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = saveTempPDF() {
                    ShareSheet(items: [url])
                }
            }
            .alert(item: $activeAlert) { alertType in
                switch alertType {
                case .success:
                    return Alert(
                        title: Text("PDF đã được lưu"),
                        message: Text("File đã được lưu vào thư mục Documents"),
                        primaryButton: .default(Text("Mở Files")) {
                            if let url = savedURL {
                                UIApplication.shared.open(url)
                            }
                        },
                        secondaryButton: .cancel(Text("OK"))
                    )
                case .error:
                    return Alert(
                        title: Text("Lỗi"),
                        message: Text(errorMessage ?? "Đã xảy ra lỗi không xác định"),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
    }
    
    private func saveToFiles() {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            logger.error("Cannot access Documents directory")
            errorMessage = "Không thể truy cập thư mục Documents"
            activeAlert = .error
            return
        }
        
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: fileURL)
            savedURL = documentsPath
            activeAlert = .success
            logger.log("PDF saved successfully to: \(fileURL.path)")
        } catch {
            logger.error("Failed to save PDF: \(error.localizedDescription)")
            errorMessage = "Không thể lưu file: \(error.localizedDescription)"
            activeAlert = .error
        }
    }
    
    private func saveTempPDF() -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pdfData.write(to: tempURL)
            logger.log("Temp PDF saved for sharing: \(tempURL.path)")
            return tempURL
        } catch {
            logger.error("Failed to save temp PDF: \(error.localizedDescription)")
            errorMessage = "Không thể chia sẻ file: \(error.localizedDescription)"
            activeAlert = .error
            return nil
        }
    }
}

// MARK: - Alert Type
private enum AlertType: Identifiable {
    case success
    case error
    
    var id: Int {
        switch self {
        case .success: return 0
        case .error: return 1
        }
    }
}

// MARK: - PDFKit View Wrapper
private struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // No updates needed
    }
}

// MARK: - Share Sheet
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

// MARK: - Preview
#Preview {
    PDFPreviewView(
        pdfData: Data(),
        fileName: "Bao_cao_kiem_tra_001.pdf"
    )
}
