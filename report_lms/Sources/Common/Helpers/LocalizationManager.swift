//
//  LocalizationManager.swift
//  report_lms
//
//  Created by Hai Phan Thanh on 13/4/26.
//

import Foundation
import Combine

// MARK: - AppLanguage

enum AppLanguage: String, CaseIterable {
    case vietnamese = "vi"
    case english = "en"

    var displayName: String {
        switch self {
        case .vietnamese: return "Tiếng Việt"
        case .english: return "English"
        }
    }
}

// MARK: - LocalizationManager

final class LocalizationManager: ObservableObject {

    static let shared = LocalizationManager()

    @Published private(set) var currentLanguage: AppLanguage

    private let userDefaultsKey = "app_selected_language"

    // MARK: - Localized Strings

    private let strings: [AppLanguage: [String: String]] = [
        .vietnamese: [
            // MARK: Settings
            "settings.title": "Cài đặt",
            "settings.section.language": "Ngôn ngữ",
            "settings.language.label": "Ngôn ngữ",
            "settings.language.vietnamese": "Tiếng Việt",
            "settings.language.english": "Tiếng Anh",

            // MARK: Common
            "common.ok": "Đồng ý",
            "common.cancel": "Hủy",
            "common.save": "Lưu",
            "common.back": "Quay lại",
            "common.retry": "Thử lại",
            "common.error": "Lỗi",
            "common.done": "Xong",
            "common.or": "hoặc",
            "common.add": "Thêm",

            // MARK: Home
            "home.title": "Kiểm tra",
            "home.tab.plan": "Kế hoạch",
            "home.tab.inProgress": "Trong tiến trình",
            "home.tab.report": "Báo cáo",
            "home.alert.cloudAction": "Cloud action triggered!",

            // MARK: Login
            "login.subtitle": "Đăng nhập bằng email",
            "login.email": "Email",
            "login.password": "Mật khẩu",
            "login.forgotPassword": "Quên mật khẩu?",
            "login.button": "Đăng nhập",
            "login.button.loading": "Đang đăng nhập...",
            "login.biometric.faceID": "Đăng nhập bằng Face ID",
            "login.biometric.touchID": "Đăng nhập bằng Touch ID",
            "login.biometric.generic": "Đăng nhập sinh trắc học",

            // MARK: Forgot Password
            "forgotPassword.title": "Quên mật khẩu",
            "forgotPassword.message": "Tính năng đang được phát triển.",

            // MARK: Menu
            "menu.title": "Menu",
            "menu.profile": "Hồ sơ",
            "menu.settings": "Cài đặt",
            "menu.orders": "Đơn hàng",
            "menu.logout": "Đăng xuất",

            // MARK: Orders
            "orders.title": "Đơn hàng",
            "orders.search.placeholder": "Tìm mã đơn, công ty, sản phẩm...",
            "orders.filter.all": "Tất cả",
            "orders.empty": "Không có đơn hàng nào",
            "orders.empty.search": "Không tìm thấy kết quả",
            "orders.clearFilter": "Xóa bộ lọc",
            "orders.delete.title": "Xóa đơn hàng",
            "orders.delete.message": "Bạn có chắc chắn muốn xóa \"%@\"? Hành động này không thể hoàn tác.",
            "orders.delete.defaultName": "đơn hàng này",
            "orders.delete.confirm": "Xóa",
            "orders.stats.all": "Tất cả",
            "orders.stats.plan": "Kế hoạch",
            "orders.stats.inProgress": "Đang KT",
            "orders.stats.completed": "Hoàn thành",

            // MARK: Plan
            "plan.empty.title": "Không có yêu cầu kiểm tra nào được tải xuống",
            "plan.empty.subtitle": "Nhấn button bên dưới để xem thêm",
            "plan.loadMore": "Tải thêm yêu cầu kiểm hàng",

            // MARK: Progress
            "progress.empty.title": "Không có yêu cầu nào đang trong tiến trình",
            "progress.empty.subtitle": "Các yêu cầu đang kiểm tra sẽ hiển thị tại đây",

            // MARK: Report
            "report.empty.title": "Chưa có báo cáo nào",
            "report.empty.subtitle": "Các đơn kiểm tra hoàn thành sẽ hiển thị tại đây",

            // MARK: Error Home
            "errorHome.empty.title": "Chưa có lỗi nào",
            "errorHome.empty.subtitle": "Nhấn nút cam bên dưới để ghi nhận lỗi mới",

            // MARK: Error Review
            "errorReview.title.new": "Đánh giá ảnh chụp",
            "errorReview.title.edit": "Chỉnh sửa lỗi",
            "errorReview.section.images": "Ảnh đã chụp",
            "errorReview.images.empty": "Chưa có ảnh nào",
            "errorReview.section.takeMorePhotos": "Chụp thêm ảnh",
            "errorReview.button.takePhoto": "Chụp ảnh",
            "errorReview.section.severity": "Mức độ nặng nhẹ",
            "errorReview.section.generalCondition": "Tình trạng chung",
            "errorReview.section.defectTypes": "Các loại phân lỗi",
            "errorReview.section.comments": "Viết nhận xét tại đây",
            "errorReview.button.delete": "Xoá",
            "errorReview.button.saveChanges": "Lưu thay đổi",
            "errorReview.delete.title": "Bạn có chắc muốn xoá lỗi này không?",
            "errorReview.delete.confirm": "Xoá lỗi",

            // MARK: Image Editor
            "imageEditor.title": "Chỉnh sửa ảnh",
            "imageEditor.addText.title": "Thêm chú thích",
            "imageEditor.addText.placeholder": "Nhập nội dung...",
            "imageEditor.menu.edit": "Chỉnh sửa",
            "imageEditor.menu.share": "Chia sẻ",
            "imageEditor.menu.delete": "Xoá bỏ",
            "imageEditor.error.downloadFailed": "Không thể tải ảnh. Vui lòng thử lại.",

            // MARK: Camera
            "camera.source.errorReport": "Báo cáo lỗi",
            "camera.source.inspection": "Chụp ảnh kiểm tra",
            "camera.source.general": "Chụp ảnh",
            "camera.permission.title": "Quyền truy cập camera",
            "camera.permission.message": "Vui lòng cấp quyền truy cập camera trong Cài đặt để sử dụng tính năng này",
            "camera.permission.openSettings": "Mở Cài đặt",
            "camera.button.cancel": "Huỷ bỏ",
            "camera.button.done": "Hoàn thành",

            // MARK: Inspection Detail
            "inspection.tab.inspection": "Kiểm tra",
            "inspection.tab.error": "Lỗi",
            "inspection.tab.info": "Thông tin",
            "inspection.button.addField": "Thêm điểm kiểm tra",
            "inspection.button.complete": "Hoàn tất kiểm tra",

            // MARK: Inspection Sections
            "inspection.section.section1": "Thùng carton ngoài",
            "inspection.section.section2": "Thùng carton trong",
            "inspection.section.section3": "Sản phẩm",
            "inspection.section.section4": "ANSI/BIFMA X5.5-2014",

            // MARK: Inspection Fields - Section 1
            "inspection.field.field1_1": "Tổng quan thùng carton",
            "inspection.field.field1_2": "Thông tin tem/nhãn vận chuyển",

            // MARK: Inspection Fields - Section 2
            "inspection.field.field2_1": "Tổng quan thùng carton trong",
            "inspection.field.field2_2": "Đóng gói (bảo vệ góc, lọc, phụ kiện, túi hút ẩm...)",

            // MARK: Inspection Fields - Section 3
            "inspection.field.field3_1": "Tổng quan sản phẩm",
            "inspection.field.field3_2": "So sánh với mẫu đã duyệt (trọng lượng, kiểu dáng, hoàn thiện, độ thoải mái...)",
            "inspection.field.field3_3": "Kích thước sản phẩm",
            "inspection.field.field3_4": "Logo trên sản phẩm",
            "inspection.field.field3_5": "Nhãn sản phẩm (nhãn hướng dẫn, nhãn cảnh báo)",
            "inspection.field.field3_6": "Hướng dẫn lắp ráp",
            "inspection.field.field3_7": "Chỉ số độ ẩm",
            "inspection.field.field3_8": "Chỉ số độ bóng",
            "inspection.field.field3_9": "So sánh màu sắc",

            // MARK: Inspection Fields - Section 4
            "inspection.field.field4_1": "Trọng lượng của quả cân",
            "inspection.field.field4_2": "Ảnh quả cân cần áp dụng",
            "inspection.field.field4_3": "Ảnh quả cân đặt trên bàn ở vị trí đúng",
            "inspection.field.field4_4": "Dữ liệu nhập phải là lượng cân và kết quả đạt/không đạt",

            // MARK: Final Report
            "finalReport.title": "Hoàn tất kiểm tra",
            "finalReport.section.quantity": "Số lượng",
            "finalReport.section.status": "Trạng thái",
            "finalReport.section.location": "Vị trí",
            "finalReport.location.placeholder": "Nhập vị trí kiểm tra",
            "finalReport.section.summary": "Tóm tắt nhận xét",
            "finalReport.section.notification": "Thông báo",
            "finalReport.section.email": "Email người nhận",
            "finalReport.email.placeholder": "Nhập địa chỉ email",
            "finalReport.queue.title": "Đã gửi yêu cầu",
            "finalReport.queue.message": "Báo cáo đang được xử lý và sẽ được gửi đến người nhận trong giây lát.",
            "finalReport.section.endInspection": "Kết thúc kiểm tra",
            "finalReport.quantity.order": "Số lượng đơn hàng",
            "finalReport.quantity.actual": "Số lượng thực tế đã xong",
            "finalReport.quantity.aql": "Số lượng cần kiểm tra theo AQL",
            "finalReport.quantity.inspected": "Số lượng đã kiểm tra",
            "finalReport.button.viewPDF": "Xem PDF",
            "finalReport.button.sendEmail": "Gửi Email",
            "finalReport.button.savePhotos": "Lưu vào tập ảnh",
            "finalReport.loading.pdf": "Đang tạo PDF...",
            "finalReport.loading.savePhotos": "Đang lưu ảnh...",
            "finalReport.recipients.title": "Chọn người nhận",
            "finalReport.recipients.done": "Xong",
            "finalReport.notification.info": "Khi báo cáo đã hoàn tất và được tải lên, email thông báo sẽ được gửi tới",
            "finalReport.success.email.title": "Gửi thành công",
            "finalReport.success.email.message": "Email báo cáo đã được gửi",
            "finalReport.success.save.title": "Lưu thành công",
            "finalReport.success.save.message": "Đã lưu %d ảnh vào thư viện",
            "finalReport.error.photoSave.title": "Lỗi lưu ảnh",
            "finalReport.error.emailUnavailable.title": "Email không khả dụng",
            "finalReport.error.emailUnavailable.message": "Thiết bị này chưa được cấu hình email. Vui lòng thiết lập tài khoản email trong Cài đặt.",
        ],
        .english: [
            // MARK: Settings
            "settings.title": "Settings",
            "settings.section.language": "Language",
            "settings.language.label": "Language",
            "settings.language.vietnamese": "Vietnamese",
            "settings.language.english": "English",

            // MARK: Common
            "common.ok": "OK",
            "common.cancel": "Cancel",
            "common.save": "Save",
            "common.back": "Back",
            "common.retry": "Retry",
            "common.error": "Error",
            "common.done": "Done",
            "common.or": "or",
            "common.add": "Add",

            // MARK: Home
            "home.title": "Inspection",
            "home.tab.plan": "Plan",
            "home.tab.inProgress": "In Progress",
            "home.tab.report": "Report",
            "home.alert.cloudAction": "Cloud action triggered!",

            // MARK: Login
            "login.subtitle": "Sign in with email",
            "login.email": "Email",
            "login.password": "Password",
            "login.forgotPassword": "Forgot password?",
            "login.button": "Sign In",
            "login.button.loading": "Signing in...",
            "login.biometric.faceID": "Sign in with Face ID",
            "login.biometric.touchID": "Sign in with Touch ID",
            "login.biometric.generic": "Biometric sign in",

            // MARK: Forgot Password
            "forgotPassword.title": "Forgot Password",
            "forgotPassword.message": "This feature is under development.",

            // MARK: Menu
            "menu.title": "Menu",
            "menu.profile": "Profile",
            "menu.settings": "Settings",
            "menu.orders": "Orders",
            "menu.logout": "Logout",

            // MARK: Orders
            "orders.title": "Orders",
            "orders.search.placeholder": "Search order code, company, product...",
            "orders.filter.all": "All",
            "orders.empty": "No orders found",
            "orders.empty.search": "No results found",
            "orders.clearFilter": "Clear filter",
            "orders.delete.title": "Delete order",
            "orders.delete.message": "Are you sure you want to delete \"%@\"? This action cannot be undone.",
            "orders.delete.defaultName": "this order",
            "orders.delete.confirm": "Delete",
            "orders.stats.all": "All",
            "orders.stats.plan": "Plan",
            "orders.stats.inProgress": "In Progress",
            "orders.stats.completed": "Completed",

            // MARK: Plan
            "plan.empty.title": "No inspection requests downloaded",
            "plan.empty.subtitle": "Tap the button below to load more",
            "plan.loadMore": "Load more inspection requests",

            // MARK: Progress
            "progress.empty.title": "No requests in progress",
            "progress.empty.subtitle": "Requests being inspected will appear here",

            // MARK: Report
            "report.empty.title": "No reports yet",
            "report.empty.subtitle": "Completed inspections will appear here",

            // MARK: Error Home
            "errorHome.empty.title": "No errors recorded",
            "errorHome.empty.subtitle": "Tap the orange button below to report a new error",

            // MARK: Error Review
            "errorReview.title.new": "Review Photos",
            "errorReview.title.edit": "Edit Error",
            "errorReview.section.images": "Captured Photos",
            "errorReview.images.empty": "No photos yet",
            "errorReview.section.takeMorePhotos": "Take More Photos",
            "errorReview.button.takePhoto": "Take Photo",
            "errorReview.section.severity": "Severity Level",
            "errorReview.section.generalCondition": "General Condition",
            "errorReview.section.defectTypes": "Defect Types",
            "errorReview.section.comments": "Add comments here",
            "errorReview.button.delete": "Delete",
            "errorReview.button.saveChanges": "Save Changes",
            "errorReview.delete.title": "Are you sure you want to delete this error?",
            "errorReview.delete.confirm": "Delete Error",

            // MARK: Image Editor
            "imageEditor.title": "Edit Image",
            "imageEditor.addText.title": "Add Annotation",
            "imageEditor.addText.placeholder": "Enter text...",
            "imageEditor.menu.edit": "Edit",
            "imageEditor.menu.share": "Share",
            "imageEditor.menu.delete": "Delete",
            "imageEditor.error.downloadFailed": "Could not download image. Please try again.",

            // MARK: Camera
            "camera.source.errorReport": "Error Report",
            "camera.source.inspection": "Inspection Photo",
            "camera.source.general": "Take Photo",
            "camera.permission.title": "Camera Access",
            "camera.permission.message": "Please grant camera access in Settings to use this feature",
            "camera.permission.openSettings": "Open Settings",
            "camera.button.cancel": "Cancel",
            "camera.button.done": "Done",

            // MARK: Inspection Detail
            "inspection.tab.inspection": "Inspection",
            "inspection.tab.error": "Error",
            "inspection.tab.info": "Information",
            "inspection.button.addField": "Add Inspection Point",
            "inspection.button.complete": "Complete Inspection",

            // MARK: Inspection Sections
            "inspection.section.section1": "Outer Carton",
            "inspection.section.section2": "Inner Carton",
            "inspection.section.section3": "Product",
            "inspection.section.section4": "ANSI/BIFMA X5.5-2014",

            // MARK: Inspection Fields - Section 1
            "inspection.field.field1_1": "Carton overview",
            "inspection.field.field1_2": "Shipping mark info",

            // MARK: Inspection Fields - Section 2
            "inspection.field.field2_1": "Inner carton overview",
            "inspection.field.field2_2": "Packaging (corner protection, filter, hardware, silica gel...)",

            // MARK: Inspection Fields - Section 3
            "inspection.field.field3_1": "Product view",
            "inspection.field.field3_2": "Compare with approved sample (weight, style, finish, comfort...)",
            "inspection.field.field3_3": "Product dimension",
            "inspection.field.field3_4": "Logo on product",
            "inspection.field.field3_5": "Product label (Tip label, warning label)",
            "inspection.field.field3_6": "Assembly instruction",
            "inspection.field.field3_7": "Moisture Readings",
            "inspection.field.field3_8": "Sheen Readings",
            "inspection.field.field3_9": "Color Comparison",

            // MARK: Inspection Fields - Section 4
            "inspection.field.field4_1": "Weight of weights",
            "inspection.field.field4_2": "Pictures of the weights to be applied",
            "inspection.field.field4_3": "Pictures of the weights on the table in the correct position",
            "inspection.field.field4_4": "Data to enter should be the amount of weight and pass/fail",

            // MARK: Final Report
            "finalReport.title": "Complete Inspection",
            "finalReport.section.quantity": "Quantity",
            "finalReport.section.status": "Status",
            "finalReport.section.location": "Location",
            "finalReport.location.placeholder": "Enter inspection location",
            "finalReport.section.summary": "Summary Comments",
            "finalReport.section.notification": "Notification",
            "finalReport.section.email": "Recipient Email",
            "finalReport.email.placeholder": "Enter email address",
            "finalReport.queue.title": "Request Submitted",
            "finalReport.queue.message": "Your report is being processed and will be sent to recipients shortly.",
            "finalReport.section.endInspection": "End Inspection",
            "finalReport.quantity.order": "Order Quantity",
            "finalReport.quantity.actual": "Actual Completed Quantity",
            "finalReport.quantity.aql": "AQL Inspection Quantity",
            "finalReport.quantity.inspected": "Inspected Quantity",
            "finalReport.button.viewPDF": "View PDF",
            "finalReport.button.sendEmail": "Send Email",
            "finalReport.button.savePhotos": "Save to Photo Album",
            "finalReport.loading.pdf": "Generating PDF...",
            "finalReport.loading.savePhotos": "Saving photos...",
            "finalReport.recipients.title": "Select Recipients",
            "finalReport.recipients.done": "Done",
            "finalReport.notification.info": "When the report is completed and uploaded, notification emails will be sent to",
            "finalReport.success.email.title": "Sent Successfully",
            "finalReport.success.email.message": "Report email has been sent",
            "finalReport.success.save.title": "Saved Successfully",
            "finalReport.success.save.message": "Saved %d photos to library",
            "finalReport.error.photoSave.title": "Photo Save Error",
            "finalReport.error.emailUnavailable.title": "Email Unavailable",
            "finalReport.error.emailUnavailable.message": "This device is not configured for email. Please set up an email account in Settings.",
        ]
    ]

    // MARK: - Init

    private init() {
        let saved = UserDefaults.standard.string(forKey: "app_selected_language") ?? AppLanguage.vietnamese.rawValue
        currentLanguage = AppLanguage(rawValue: saved) ?? .vietnamese
    }

    // MARK: - Public Methods

    func setLanguage(_ language: AppLanguage) {
        guard language != currentLanguage else { return }
        currentLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: userDefaultsKey)
    }

    func localize(_ key: String) -> String {
        return strings[currentLanguage]?[key] ?? key
    }

    func localize(_ key: String, _ args: CVarArg...) -> String {
        let format = strings[currentLanguage]?[key] ?? key
        return String(format: format, arguments: args)
    }
}
