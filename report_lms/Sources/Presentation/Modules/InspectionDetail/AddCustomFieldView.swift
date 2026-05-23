//
//  AddCustomFieldView.swift
//  report_lms
//
//  Created by GitHub Copilot on 3/3/26.
//

import SwiftUI

struct AddCustomFieldView: View {
    // MARK: - Constants
    private enum Layout {
        static let spacing: CGFloat = 16
        static let padding: CGFloat = 20
        static let buttonHeight: CGFloat = 50
    }
    
    // MARK: - Properties
    @Environment(\.dismiss) private var dismiss
    @State private var fieldLabel: String = ""
    @State private var fieldType: InspectionField.FieldType = .photo
    @State private var formVisible = false
    
    let onSave: (String, InspectionField.FieldType) -> Void
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            VStack(spacing: Layout.spacing) {
                // Field Label Input
                VStack(alignment: .leading, spacing: 8) {
                    LMSLabel("Tên điểm kiểm tra", style: .body)
                        .fontWeight(.semibold)

                    LMSTextField(
                        "Nhập tên điểm kiểm tra",
                        text: $fieldLabel
                    )
                }
                .opacity(formVisible ? 1 : 0)
                .offset(y: formVisible ? 0 : 16)
                .animation(.easeOut(duration: 0.35), value: formVisible)

                // Field Type Picker
                VStack(alignment: .leading, spacing: 8) {
                    LMSLabel("Loại điểm kiểm tra", style: .body)
                        .fontWeight(.semibold)

                    Picker("Loại", selection: $fieldType) {
                        ForEach([InspectionField.FieldType.photo, .text, .checkbox], id: \.self) { type in
                            Text(fieldTypeLabel(for: type))
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .opacity(formVisible ? 1 : 0)
                .offset(y: formVisible ? 0 : 16)
                .animation(.easeOut(duration: 0.35).delay(0.08), value: formVisible)

                Spacer()

                // Save Button
                LMSButton(
                    "Thêm điểm kiểm tra",
                    icon: "plus.circle.fill",
                    variant: .primary,
                    action: {
                        guard !fieldLabel.isEmpty else { return }
                        onSave(fieldLabel, fieldType)
                        dismiss()
                    }
                )
                .frame(height: Layout.buttonHeight)
                .disabled(fieldLabel.isEmpty)
                .opacity(formVisible ? 1 : 0)
                .offset(y: formVisible ? 0 : 12)
                .animation(.easeOut(duration: 0.35).delay(0.16), value: formVisible)
            }
            .padding(Layout.padding)
            .navigationTitle("Thêm điểm kiểm tra")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Hủy") {
                        dismiss()
                    }
                }
            }
            .task {
                withAnimation(.easeOut(duration: 0.35)) { formVisible = true }
            }
        }
    }
    
    // MARK: - Private Methods
    private func fieldTypeLabel(for type: InspectionField.FieldType) -> String {
        switch type {
        case .photo:
            return "Hình ảnh"
        case .text:
            return "Văn bản"
        case .checkbox:
            return "Hộp kiểm"
        case .number:
            return "Số"
        }
    }
}

// MARK: - Preview
#Preview {
    AddCustomFieldView { label, type in
        print("Field: \(label), Type: \(type)")
    }
}
