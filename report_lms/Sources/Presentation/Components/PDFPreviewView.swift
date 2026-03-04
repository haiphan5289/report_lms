//
//  PDFPreviewView.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/4/26.
//

import SwiftUI
import PDFKit

/// SwiftUI wrapper for PDFView to preview PDF documents
struct PDFPreviewView: View {
    let pdfData: Data
    let fileName: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var showShareSheet = false
    @State private var showSaveAlert = false
    @State private var savedURL: URL?
    
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
                    
                    // Share button
                    Button(action: { showShareSheet = true }) {
                        Label("Chia sẻ", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
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
            .alert("PDF đã được lưu", isPresented: $showSaveAlert) {
                Button("Mở Files") {
                    if let url = savedURL {
                        UIApplication.shared.open(url)
                    }
                }
                Button("OK") { }
            } message: {
                Text("File đã được lưu vào thư mục Documents")
            }
        }
    }
    
    private func saveToFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = documentsPath.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: fileURL)
            savedURL = documentsPath
            showSaveAlert = true
        } catch {
            print("Error saving PDF: \(error.localizedDescription)")
        }
    }
    
    private func saveTempPDF() -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        do {
            try pdfData.write(to: tempURL)
            return tempURL
        } catch {
            return nil
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
