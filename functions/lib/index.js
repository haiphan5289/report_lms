"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.processReportQueue = void 0;
const admin = __importStar(require("firebase-admin"));
const firestore_1 = require("firebase-functions/v2/firestore");
const params_1 = require("firebase-functions/params");
const nodemailer = __importStar(require("nodemailer"));
const pdfkit_1 = __importDefault(require("pdfkit"));
const path = __importStar(require("path"));
const fs = __importStar(require("fs"));
const https = __importStar(require("https"));
const sharp_1 = __importDefault(require("sharp"));
admin.initializeApp();
const gmailUser = (0, params_1.defineSecret)("GMAIL_USER");
const gmailPass = (0, params_1.defineSecret)("GMAIL_APP_PASSWORD");
const FONTS_DIR = path.join(__dirname, "..", "fonts");
const FONT_REGULAR = path.join(FONTS_DIR, "NotoSans-Regular.ttf");
const FONT_BOLD = path.join(FONTS_DIR, "NotoSans-Bold.ttf");
// ── Qarma-style layout — mirrors iOS PDFKitGeneratorService ───────────────────
const MARGIN = 40;
const PAGE_H = 841.89;
const CW = 515.28; // A4 content width = 595.28 - 2*40
const FOOTER_Y = PAGE_H - 28;
const CONTENT_MAX_Y = PAGE_H - 46;
// 4-column photo grid
const IMGS_PER_ROW = 4;
const IMG_GAP = 8;
const IMG_W = (CW - IMG_GAP * (IMGS_PER_ROW - 1)) / IMGS_PER_ROW; // ≈122.8
const IMG_H = IMG_W * 0.75; // ≈92.1
const INFO_ROW_H = 26;
const TABLE_ROW_H = 24;
// ── Colors ─────────────────────────────────────────────────────────────────────
const C_WHITE = "#ffffff";
const C_DARK = "#222222";
const C_MID = "#404040";
const C_GRAY = "#666666";
const C_FOOTER = "#aaaaaa";
const C_BLUE = "#3366cc";
const C_BORDER = "#c8c8c8";
const C_LABEL_BG = "#f5f5f5";
const C_HDR_BG = "#f2f2f2";
const C_CRITICAL = "#c62626";
const C_MAJOR = "#e5990d";
const C_MINOR = "#2473cc";
const C_GREEN = "#33a14a";
const TRANSLATIONS = {
    vi: {
        reportTitle: "Báo cáo kiểm tra, Hoàn tất:",
        inspector: "Người kiểm tra",
        inspectionDate: "Ngày kiểm tra",
        plannedSample: "Mẫu KH/Thực tế",
        orderQty: "SL đơn hàng",
        location: "Vị trí",
        checklistName: "Tên checklist",
        checklistNameValue: "Danh sách kiểm tra cuối",
        plannedDate: "Ngày kế hoạch",
        samplingMethod: "Phương pháp",
        samplingMethodValue: "Kiểm tra 100%",
        supplierName: "Tên nhà máy",
        inspectorConclusion: "Kết luận kiểm tra",
        statusBanner: "Trạng thái:",
        summary: "TÓM TẮT",
        fieldComment: "Nhận xét:",
        checklistSection: "Hạng mục kiểm tra",
        statusColumn: "Trạng thái",
        accepted: "ĐẠT",
        pending: "CHỜ XEM XÉT",
        rejected: "KHÔNG ĐẠT",
        footer: "Báo cáo tạo bởi report_lms.",
        emailSubject: "Báo cáo kiểm tra #",
        emailHeader: "Báo cáo kiểm tra #",
        emailGreeting: "Kính gửi,",
        emailBody: "Đính kèm là báo cáo kiểm tra <strong>#%n</strong>.",
        emailCta: "Vui lòng xem file PDF đính kèm để biết chi tiết.",
        emailClosing: "Trân trọng,",
        emailFooter: "Gửi tự động bởi LMS Report App",
        attachmentPrefix: "Bao_cao_kiem_tra_",
        defectsSection: "LỖI PHÁT HIỆN",
        defectTypeOther: "Khác",
    },
    en: {
        reportTitle: "Inspection report, Final:",
        inspector: "Inspector",
        inspectionDate: "Inspection Date",
        plannedSample: "Planned Sample/Insp.",
        orderQty: "Order Qty",
        location: "Location",
        checklistName: "Checklist Name",
        checklistNameValue: "Final CheckList",
        plannedDate: "Planned Date",
        samplingMethod: "Sampling Method",
        samplingMethodValue: "100% inspection",
        supplierName: "Supplier Name",
        inspectorConclusion: "Inspector Conclusion",
        statusBanner: "Status:",
        summary: "SUMMARY",
        fieldComment: "Comment:",
        checklistSection: "Checklist Section",
        statusColumn: "Status",
        accepted: "ACCEPTED",
        pending: "PENDING",
        rejected: "REJECTED",
        footer: "Report created with report_lms.",
        emailSubject: "Inspection Report #",
        emailHeader: "Inspection Report #",
        emailGreeting: "Dear,",
        emailBody: "Please find attached the inspection report <strong>#%n</strong>.",
        emailCta: "Please review the attached PDF for details.",
        emailClosing: "Best regards,",
        emailFooter: "Sent automatically by LMS Report App",
        attachmentPrefix: "Inspection_Report_",
        defectsSection: "DEFECTS FOUND",
        defectTypeOther: "Other",
    },
};
function t(lang, key) {
    var _a, _b, _c;
    return (_c = (_b = (_a = TRANSLATIONS[lang]) === null || _a === void 0 ? void 0 : _a[key]) !== null && _b !== void 0 ? _b : TRANSLATIONS["en"][key]) !== null && _c !== void 0 ? _c : key;
}
/**
 * Mirrors `DefectType.name` in iOS `ErrorItem.swift` — Vietnamese-only, no English
 * variant exists on either side. Keep in sync manually if the iOS enum changes.
 */
const DEFECT_TYPE_NAMES = {
    // PA - Đóng gói sản phẩm
    "PA-1": "Thiếu cảnh báo và ký hiệu an toàn",
    "PA-2": "Hướng dẫn lắp ráp",
    "PA-3": "Bao nylon không đục lỗ",
    "PA-4": "Thông tin bao bì và nhãn dán",
    "PA-5": "Đóng gói: dán kín và chặt",
    "PA-6": "Sai mã vạch và thông tin đơn hàng",
    "PA-7": "Bảo vệ góc",
    "PA-8": "Test đóng gói",
    "PA-9": "Thùng carton bị hư hỏng, ẩm ướt, đè nát, biến dạng",
    "PA-10": "Kích thước và cân nặng",
    "PA-11": "Vật lạ (côn trùng, sâu bọ, v.v)",
    "PA-12": "Mùi hôi",
    "PA-13": "Ray trượt không có che chắn chống trượt",
    "PA-14": "Không có mút carton góc",
    "PA-15": "Vật tư đóng gói ngắn, k đúng kích thước",
    "PA-16": "Chân không được quấn trong bao bong bóng",
    "PA-17": "Chân không được bỏ trong ngăn trống với dây kéo",
    "PA-18": "Thiếu vật tư điện nếu có",
    "PA-19": "Không có bịch chống ẩm",
    "PA-20": "Gối không được bỏ vào bao ni lông",
    "PA-21": "Đóng gói không chặt, di chuyển trong thùng",
    "PA-22": "Không có màng foam hay giấy lót bảo vệ tay",
    "PA-23": "Không có màng foam hay giấy lót bảo vệ lưng",
    "PA-24": "Carton góc không có",
    "PA-25": "Khác",
    // SU - Bề mặt sản phẩm
    "SU-1": "Thiếu lớp phủ/sơn/phun/in/sơn tĩnh điện",
    "SU-2": "Sai hình dạng, biến dạng và không đối xứng",
    "SU-3": "Bề mặt không bằng phẳng và mức độ không đồng đều",
    "SU-4": "Trầy xước, cấn móp, mè cạnh",
    "SU-5": "Bụi bẩn và các vết (keo, vết lõm, sứt mẻ, rạn nứt)",
    "SU-6": "Thiếu mối hàn",
    "SU-7": "Thiếu chà nhám",
    "SU-8": "Gỉ sét",
    "SU-9": "Nứt",
    "SU-10": "Dung sai mắt chết",
    "SU-11": "Khác",
    // AS - Lắp ráp
    "AS-1": "Lắp ráp chưa hoàn chỉnh",
    "AS-2": "Sai hoặc thiếu phụ kiện",
    "AS-3": "Chi tiết và phụ kiện lắp ráp không phù hợp",
    "AS-4": "Hở mối ghép",
    "AS-5": "Các phần nối không thẳng",
    "AS-6": "Kết nối lỏng lẻo",
    "AS-7": "Thiếu ốc để ráp chân",
    "AS-8": "Hướng dẫn lắp ráp không đúng",
    "AS-9": "Khác",
    // FU - Chức năng và kiểm tra
    "FU-1": "Kiểm tra tải",
    "FU-2": "Không ổn định",
    "FU-3": "Độ ẩm và nấm",
    "FU-4": "Tiếng ồn không cần thiết",
    "FU-5": "Ghế bạt không hoạt động dễ dàng",
    "FU-6": "Đỡ chân không đẩy ra dễ dàng",
    "FU-7": "Đỡ chân không chắc chắn",
    "FU-8": "Ghế bạt điện không hoạt động trơn tru ở tất cả các vị trí",
    "FU-9": "USB không hoạt động",
    "FU-10": "Bluetooth không hoạt động",
    "FU-11": "Nắp cửa console không đứng yên khi nâng lên",
    "FU-12": "Phần đính kèm không hoạt động tốt",
    "FU-13": "Khác",
    // SA - An toàn
    "SA-1": "Mảnh vụn",
    "SA-2": "Cạnh/Điểm bén nhọn",
    "SA-3": "Thiếu cảnh báo",
    "SA-4": "Vật liệu chống cháy",
    "SA-5": "Khác",
    // FI - Finishing
    "FI-1": "Tróc, chảy, phồng độp",
    "FI-2": "Dấu vân tay, sần",
    "FI-3": "Khu vực không có màu",
    "FI-4": "Màu không đồng nhất",
    "FI-5": "Giả cổ ngẫu nhiên",
    "FI-6": "Xử lý gỗ",
    "FI-7": "Dính keo",
    "FI-8": "Không có sơn/sản ở liên kết",
    "FI-9": "Sơn trong lòng hộc kéo",
    "FI-10": "Không quá nhiều mắt trên mặt",
    "FI-11": "Không quá nhiều mắt trên hông",
    "FI-12": "Không quá nhiều mắt trên mặt hộc kéo",
    "FI-13": "Nứt trên mắt gỗ",
    "FI-14": "Đinh/vít phồng",
    "FI-15": "Lỗ đinh",
    "FI-16": "Công vênh ở mặt/hông",
    "FI-17": "Chà nhám lõm",
    "FI-18": "Mặt hộc không thẳng",
    "FI-19": "Võng mặt/hông",
    "FI-20": "Trầy veneer",
    "FI-21": "Không khớp chiều veneer",
    "FI-22": "Tróc veneer",
    "FI-23": "Nhám cạnh",
    "FI-24": "Khác",
    // CO - Construction
    "CO-1": "Mối ghép phẳng",
    "CO-2": "Khe hở o mới ghép",
    "CO-3": "Ghép không thẳng",
    "CO-4": "Keo/dầu/trầy trên nỉ",
    "CO-5": "Nứt trong hộc kéo",
    "CO-6": "Ke gốc cho khung",
    "CO-7": "Khung đỡ hộc",
    "CO-8": "Khung đỡ hộc khi loại bỏ hộc kéo",
    "CO-9": "Hộc kéo đóng/mở không dễ dàng",
    "CO-10": "Cửa đóng/mở không dễ dàng",
    "CO-11": "Độ ngã không đúng",
    "CO-12": "Thiếu foam ở lưng, tay, ngồi",
    "CO-13": "Khung bị võng ở giữa",
    "CO-14": "Lưng tựa không có gia cố",
    "CO-15": "Nệm không có cố định",
    "CO-16": "Nệm không có 2 mặt",
    "CO-17": "Khác",
    // FE - Features
    "FE-1": "Chiều sâu hộc kéo không đều",
    "FE-2": "Không có ván bắn ở phía sau để chống lật",
    "FE-3": "Không có ván ngăn bụi giữa các hộc kéo",
    "FE-4": "Đinh trang trí không thẳng",
    "FE-5": "Đinh trang trí không đều khoảng cách",
    "FE-6": "Mặt đá có dính nhựa sửa",
    "FE-7": "Mặt đá khác màu",
    "FE-8": "Bọc nệm không chặt",
    "FE-9": "Không có đủ chất độn",
    "FE-10": "Nhăn, hở ở cạnh/nút",
    "FE-11": "Khác",
    // TA - Tailoring
    "TA-1": "Đường may không thẳng",
    "TA-2": "Chỉ không chặt chẽ trong đường may",
    "TA-3": "Chỉ lỏng lẻo",
    "TA-4": "Đường viền không thẳng",
    "TA-5": "Vải không bó chặt vào khung",
    "TA-6": "Vết nhăn trên da",
    "TA-7": "Đường chỉ không thẳng",
    "TA-8": "Rách",
    "TA-9": "Đường may, đường khâu bị bung và đầu sợi chỉ thừa chưa được cắt",
    "TA-10": "Bọc không đạt",
    "TA-11": "Khác",
};
/** Mirrors `DefectType.displayName` on iOS: "{code} - {name}". Falls back to the localized "Other" label when no code was selected. */
function defectTitle(code, lang) {
    if (!code)
        return t(lang, "defectTypeOther");
    const name = DEFECT_TYPE_NAMES[code];
    return name ? `${code} - ${name}` : code;
}
/** Maps a `SavedErrorItem.severity` raw label (Vietnamese, written by the iOS app) to a defect-table color/column. */
function severityColor(severity) {
    return severity === "Nghiêm trọng" ? C_CRITICAL : severity === "Nặng" ? C_MAJOR : C_MINOR;
}
/** Counts errorItems by severity for the CRITICAL/MAJOR/MINOR table — unrecognized/"Nhẹ" values count as minor. */
function countBySeverity(items) {
    let critical = 0, major = 0, minor = 0;
    for (const item of items) {
        if (item.severity === "Nghiêm trọng")
            critical++;
        else if (item.severity === "Nặng")
            major++;
        else
            minor++;
    }
    return { critical, major, minor };
}
function isValidEmail(value) {
    return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}
/** Strip characters unsafe for a filename/email attachment name, turning dashes into spaces. */
function sanitizeFilenamePart(value) {
    return value.trim().replace(/[\\/:*?"<>|]/g, "").replace(/-/g, " ").replace(/\s+/g, " ");
}
/** Formats a Date as Vietnam local (Asia/Ho_Chi_Minh) date + time, independent of the server's own timezone. */
function vnDateTimeParts(d) {
    const parts = new Intl.DateTimeFormat("en-US", {
        timeZone: "Asia/Ho_Chi_Minh",
        year: "numeric", month: "2-digit", day: "2-digit",
        hour: "2-digit", minute: "2-digit", hourCycle: "h23",
    }).formatToParts(d);
    const get = (type) => { var _a, _b; return (_b = (_a = parts.find((p) => p.type === type)) === null || _a === void 0 ? void 0 : _a.value) !== null && _b !== void 0 ? _b : ""; };
    return {
        date: `${get("month")}/${get("day")}/${get("year")}`,
        time: `${get("hour")}:${get("minute")}`,
    };
}
/** Turn an email local-part into a display name, e.g. "hai.phan@chotot.vn" -> "Hai Phan". Non-email values (e.g. "unknown") pass through unchanged. */
function deriveDisplayName(value) {
    const at = value.indexOf("@");
    if (at <= 0)
        return value;
    return value.slice(0, at)
        .split(".")
        .filter(Boolean)
        .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
        .join(" ");
}
/** Parses a user-entered mm measurement string (comma or dot decimal separator). Returns null if empty/invalid. */
function parseMM(value) {
    if (!value || !value.trim())
        return null;
    const n = parseFloat(value.replace(",", "."));
    return Number.isFinite(n) ? n : null;
}
// ── Cloud Function ─────────────────────────────────────────────────────────────
exports.processReportQueue = (0, firestore_1.onDocumentCreated)({
    document: "report_delivery_queue/{taskId}",
    secrets: [gmailUser, gmailPass],
    region: "asia-southeast1",
    timeoutSeconds: 120,
    memory: "512MiB",
}, async (event) => {
    var _a;
    const taskId = event.params.taskId;
    const db = admin.firestore();
    const taskRef = db.collection("report_delivery_queue").doc(taskId);
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data) {
        console.error(`[${taskId}] No data in document`);
        return;
    }
    const { inspectionId, inspectionNumber, recipientEmails, location, requestedBy, requestedByDisplayName, finalStatus = "pending", summaryComments = "", language = "vi", } = data;
    const lang = (language === "en" ? "en" : "vi");
    // Prefer the Profile-screen display name; fall back to deriving one from the email
    // for tasks queued before requestedByDisplayName existed.
    const displayName = requestedByDisplayName || (requestedBy ? deriveDisplayName(requestedBy) : "");
    await taskRef.update({ status: "processing" });
    console.log(`[${taskId}] Generating Qarma PDF for #${inspectionNumber}`);
    try {
        const snap = await db.collection("inspections").doc(inspectionId).get();
        const inspection = snap.data();
        if (!inspection)
            throw new Error(`Inspection ${inspectionId} not found`);
        const errorItemsSnap = await db
            .collection("inspections").doc(inspectionId)
            .collection("errorItems")
            .orderBy("createdAt", "desc")
            .get();
        const errorItems = errorItemsSnap.docs.map((d) => {
            var _a, _b, _c;
            const ed = d.data();
            return {
                id: d.id,
                imageURLs: Array.isArray(ed.imageURLs) ? ed.imageURLs : [],
                severity: (_a = ed.severity) !== null && _a !== void 0 ? _a : "Nhẹ",
                defectType: ed.defectType,
                comments: (_b = ed.comments) !== null && _b !== void 0 ? _b : "",
                createdAt: (_c = ed.createdAt) !== null && _c !== void 0 ? _c : "",
            };
        });
        const pdfBuffer = await generatePDF(inspection, inspectionNumber, location, displayName, finalStatus, summaryComments, lang, errorItems);
        console.log(`[${taskId}] PDF generated: ${pdfBuffer.length} bytes`);
        // Upload to Firebase Storage so the iOS app can retrieve it later
        const storagePath = `inspections/${inspectionId}/reports/${taskId}.pdf`;
        const bucket = admin.storage().bucket();
        const file = bucket.file(storagePath);
        await file.save(pdfBuffer, { metadata: { contentType: "application/pdf" } });
        await taskRef.update({ pdfStoragePath: storagePath });
        console.log(`[${taskId}] PDF uploaded to Storage: ${storagePath}`);
        const transporter = nodemailer.createTransport({
            service: "gmail",
            auth: { user: gmailUser.value(), pass: gmailPass.value() },
        });
        // requestedBy falls back to the literal string "unknown" on the iOS side when no user
        // is logged in (see ReportDeliveryQueueService.enqueue) — that's not a deliverable
        // address, and handing it to nodemailer as a cc/replyTo would risk the whole send
        // being rejected by the SMTP server, including the real recipients. Only trace-cc the
        // sender when requestedBy is an actual email.
        const traceEmail = isValidEmail(requestedBy) ? requestedBy : undefined;
        await transporter.sendMail(Object.assign(Object.assign({ from: `"LMS Report" <${gmailUser.value()}>`, to: recipientEmails.join(", ") }, (traceEmail ? { cc: traceEmail, replyTo: traceEmail } : {})), { subject: `${t(lang, "emailSubject")}${inspectionNumber}`, html: buildEmailHTML(inspectionNumber, displayName, lang), attachments: [{
                    filename: `Final Report ${sanitizeFilenamePart(inspection.productName || inspectionNumber)}.pdf`,
                    content: pdfBuffer,
                    contentType: "application/pdf",
                }] }));
        console.log(`[${taskId}] Email sent to: ${recipientEmails.join(", ")}${traceEmail ? ` (cc: ${traceEmail})` : ""}`);
        await taskRef.update({ status: "sent", sentAt: admin.firestore.FieldValue.serverTimestamp() });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        console.error(`[${taskId}] Failed: ${message}`);
        try {
            await taskRef.update({ status: "failed", errorMessage: message });
        }
        catch (_b) { }
    }
});
// ── Image helpers ──────────────────────────────────────────────────────────────
async function compressImageBuffer(buf) {
    try {
        return await (0, sharp_1.default)(buf)
            .resize(800, 600, { fit: "inside", withoutEnlargement: true })
            .jpeg({ quality: 70 })
            .toBuffer();
    }
    catch (_a) {
        return buf;
    }
}
function downloadImageBuffer(url) {
    return new Promise((resolve, reject) => {
        const req = https.get(url, (res) => {
            if (res.statusCode !== 200) {
                reject(new Error(`Image fetch ${res.statusCode}: ${url}`));
                return;
            }
            const chunks = [];
            res.on("data", (c) => chunks.push(c));
            res.on("end", () => resolve(Buffer.concat(chunks)));
            res.on("error", reject);
        });
        req.on("error", reject);
        req.setTimeout(10000, () => { req.destroy(); reject(new Error("Image download timeout")); });
    });
}
/** Pre-fetch all field + defect images; process in batches of 5 to avoid memory spikes. */
async function prefetchImages(inspection, errorItems = []) {
    var _a, _b;
    const map = new Map();
    const sections = Array.isArray(inspection.sections)
        ? inspection.sections : [];
    const urls = [];
    for (const section of sections) {
        for (const field of ((_a = section.fields) !== null && _a !== void 0 ? _a : [])) {
            for (const url of ((_b = field.imageURLs) !== null && _b !== void 0 ? _b : [])) {
                if (url && !map.has(url))
                    urls.push(url);
            }
        }
    }
    for (const item of errorItems) {
        for (const url of item.imageURLs) {
            if (url && !map.has(url))
                urls.push(url);
        }
    }
    for (let i = 0; i < urls.length; i += 5) {
        await Promise.all(urls.slice(i, i + 5).map((url) => downloadImageBuffer(url)
            .then(compressImageBuffer)
            .then((buf) => { map.set(url, buf); })
            .catch((e) => { console.warn(`Skip image ${url}: ${e.message}`); })));
    }
    return map;
}
// ── PDF drawing helpers ────────────────────────────────────────────────────────
function statusColor(s) {
    return s === "accepted" ? C_GREEN : s === "rejected" ? C_CRITICAL : C_MAJOR;
}
function statusLabel(s, lang = "vi") {
    return s === "accepted" ? t(lang, "accepted")
        : s === "rejected" ? t(lang, "rejected")
            : t(lang, "pending");
}
/** Bordered cell with vertically-centred text. */
function drawCell(doc, text, x, y, w, h, opts) {
    const { bg = C_WHITE, fg = C_DARK, font = "R", size = 10, align = "left" } = opts;
    const pad = 5;
    doc.lineWidth(0.5).rect(x, y, w, h).fillAndStroke(bg, C_BORDER);
    if (text) {
        const textY = y + Math.max(3, (h - size * 1.2) / 2);
        doc.font(font).fontSize(size).fillColor(fg)
            .text(text, x + pad, textY, { width: w - pad * 2, lineBreak: false, align });
    }
}
function drawHLine(doc, y, color = "#cccccc", lw = 0.75) {
    doc.moveTo(MARGIN, y).lineTo(MARGIN + CW, y).lineWidth(lw).strokeColor(color).stroke();
}
/** Per-page footer: thin separator + left credit + right "Order:… page: N". */
function drawFooter(doc, orderInfo, dateStr, pageNum, fonts, lang = "vi") {
    drawHLine(doc, FOOTER_Y - 5, "#d0d0d0", 0.5);
    doc.font(fonts.R).fontSize(8).fillColor(C_FOOTER)
        .text(t(lang, "footer"), MARGIN, FOOTER_Y, { width: CW / 2, lineBreak: false });
    doc.font(fonts.R).fontSize(8).fillColor(C_FOOTER)
        .text(`${orderInfo}   ${dateStr}, page: ${pageNum}`, MARGIN + CW / 2, FOOTER_Y, { width: CW / 2, lineBreak: false, align: "right" });
}
/**
 * 4-column info table.
 * rows: [leftLabel, leftValue, rightLabel | null, rightValue | null]
 * When right columns are null, leftValue spans the remaining width.
 */
function drawInfoTable(doc, rows, startY, fonts) {
    const lw = CW * 0.22;
    const vw = CW * 0.28;
    let y = startY;
    for (const [ll, lv, rl, rv] of rows) {
        if (rl !== null && rv !== null) {
            drawCell(doc, ll, MARGIN, y, lw, INFO_ROW_H, { bg: C_LABEL_BG, fg: C_GRAY, font: fonts.R });
            drawCell(doc, lv, MARGIN + lw, y, vw, INFO_ROW_H, { bg: C_WHITE, fg: C_DARK, font: fonts.B });
            drawCell(doc, rl, MARGIN + lw + vw, y, lw, INFO_ROW_H, { bg: C_LABEL_BG, fg: C_GRAY, font: fonts.R });
            drawCell(doc, rv, MARGIN + lw + vw + lw, y, vw, INFO_ROW_H, { bg: C_WHITE, fg: C_DARK, font: fonts.B });
        }
        else {
            drawCell(doc, ll, MARGIN, y, lw, INFO_ROW_H, { bg: C_LABEL_BG, fg: C_GRAY, font: fonts.R });
            drawCell(doc, lv, MARGIN + lw, y, CW - lw, INFO_ROW_H, { bg: C_WHITE, fg: C_DARK, font: fonts.B });
        }
        y += INFO_ROW_H;
    }
    return y;
}
/** "Inspector Conclusion" label + coloured badge + optional notes. */
function drawConclusionRow(doc, finalStatus, summaryComments, y, fonts, lang = "vi") {
    doc.font(fonts.R).fontSize(10).fillColor(C_GRAY)
        .text(t(lang, "inspectorConclusion"), MARGIN, y + 6, { lineBreak: false });
    const label = statusLabel(finalStatus, lang);
    const color = statusColor(finalStatus);
    const badgeX = MARGIN + 140;
    doc.font(fonts.B).fontSize(9);
    const textW = doc.widthOfString(label);
    const hPad = 8, vPad = 3;
    const bW = textW + hPad * 2;
    const bH = 9 * 1.2 + vPad * 2;
    doc.roundedRect(badgeX, y + 4, bW, bH, 2).fillColor(color).fill();
    doc.font(fonts.B).fontSize(9).fillColor(C_WHITE)
        .text(label, badgeX + hPad, y + 4 + vPad, { lineBreak: false });
    let rowH = INFO_ROW_H;
    if (summaryComments) {
        const notesX = badgeX + bW + 10;
        const notesW = MARGIN + CW - notesX;
        doc.font(fonts.R).fontSize(9);
        const notesH = doc.heightOfString(summaryComments, { width: notesW });
        doc.fillColor(C_GRAY)
            .text(summaryComments, notesX, y + 6, { width: notesW });
        rowH = Math.max(rowH, notesH + 10);
    }
    return y + rowH;
}
/** Full-width coloured status banner. */
function drawStatusBanner(doc, finalStatus, y, fonts, lang = "vi") {
    const h = 26;
    doc.rect(MARGIN, y, CW, h).fillColor(statusColor(finalStatus)).fill();
    doc.font(fonts.R).fontSize(10).fillColor(C_WHITE)
        .text(t(lang, "statusBanner"), MARGIN + 10, y + 7, { lineBreak: false });
    doc.font(fonts.B).fontSize(10).fillColor(C_WHITE)
        .text(statusLabel(finalStatus, lang), MARGIN + 64, y + 7, { lineBreak: false });
    return y + h;
}
/** Checklist summary: section name | progress bar */
function drawChecklistTable(doc, sections, imageMap, startY, fonts, lang = "vi") {
    const nameW = CW * 0.82;
    const statusW = CW - nameW;
    let y = startY;
    drawCell(doc, t(lang, "checklistSection"), MARGIN, y, nameW, TABLE_ROW_H, { bg: C_HDR_BG, fg: C_DARK, font: fonts.B });
    drawCell(doc, t(lang, "statusColumn"), MARGIN + nameW, y, statusW, TABLE_ROW_H, { bg: C_HDR_BG, fg: C_DARK, font: fonts.B, align: "center" });
    y += TABLE_ROW_H;
    const sorted = [...sections].sort((a, b) => { var _a, _b; return ((_a = a.order) !== null && _a !== void 0 ? _a : 0) - ((_b = b.order) !== null && _b !== void 0 ? _b : 0); });
    sorted.forEach((sec, i) => {
        var _a;
        const fields = (_a = sec.fields) !== null && _a !== void 0 ? _a : [];
        const total = fields.length;
        const completed = fields.filter((f) => { var _a; return ((_a = f.imageURLs) !== null && _a !== void 0 ? _a : []).some((u) => imageMap.has(u)); }).length;
        const progress = total > 0 ? completed / total : 0;
        const progressColor = progress === 0 ? "#9e9e9e" :
            progress < 0.5 ? "#ff9800" :
                progress < 1.0 ? "#2196f3" :
                    C_GREEN;
        const rowBg = i % 2 === 0 ? C_WHITE : "#fafafa";
        drawCell(doc, `${i + 1}   ${sec.title}`, MARGIN, y, nameW, TABLE_ROW_H, { bg: rowBg, fg: C_DARK, font: fonts.R });
        // Status cell: background + border + progress bar
        const cellX = MARGIN + nameW;
        doc.rect(cellX, y, statusW, TABLE_ROW_H).fillColor(rowBg).fill();
        doc.rect(cellX, y, statusW, TABLE_ROW_H).lineWidth(0.5).strokeColor("#e0e0e0").stroke();
        const BAR_W = 55;
        const BAR_H = 5;
        const barX = cellX + (statusW - BAR_W) / 2;
        const barY = y + (TABLE_ROW_H - BAR_H) / 2;
        doc.rect(barX, barY, BAR_W, BAR_H).fillColor("#e0e0e0").fill();
        if (progress > 0) {
            doc.rect(barX, barY, BAR_W * progress, BAR_H).fillColor(progressColor).fill();
        }
        y += TABLE_ROW_H;
    });
    return y;
}
/** Defect count table: header row (CRITICAL / MAJOR / MINOR) + TOTAL row. */
function drawDefectTable(doc, critical, major, minor, startY, fonts) {
    const descW = CW * 0.52;
    const colW = (CW - descW) / 3;
    let y = startY;
    drawCell(doc, "", MARGIN, y, descW, TABLE_ROW_H, { bg: C_HDR_BG, fg: C_DARK, font: fonts.B });
    drawCell(doc, "CRITICAL", MARGIN + descW, y, colW, TABLE_ROW_H, { bg: C_HDR_BG, fg: C_CRITICAL, font: fonts.B, align: "center" });
    drawCell(doc, "MAJOR", MARGIN + descW + colW, y, colW, TABLE_ROW_H, { bg: C_HDR_BG, fg: C_MAJOR, font: fonts.B, align: "center" });
    drawCell(doc, "MINOR", MARGIN + descW + colW * 2, y, colW, TABLE_ROW_H, { bg: C_HDR_BG, fg: C_MINOR, font: fonts.B, align: "center" });
    y += TABLE_ROW_H;
    drawCell(doc, "TOTAL", MARGIN, y, descW, TABLE_ROW_H, { bg: C_WHITE, fg: C_DARK, font: fonts.B });
    drawCell(doc, String(critical), MARGIN + descW, y, colW, TABLE_ROW_H, { bg: C_WHITE, fg: critical > 0 ? C_CRITICAL : C_DARK, font: fonts.B, align: "center" });
    drawCell(doc, String(major), MARGIN + descW + colW, y, colW, TABLE_ROW_H, { bg: C_WHITE, fg: major > 0 ? C_MAJOR : C_DARK, font: fonts.B, align: "center" });
    drawCell(doc, String(minor), MARGIN + descW + colW * 2, y, colW, TABLE_ROW_H, { bg: C_WHITE, fg: minor > 0 ? C_MINOR : C_DARK, font: fonts.B, align: "center" });
    y += TABLE_ROW_H;
    return y;
}
/** Section heading: bold 14pt title + 1.5pt blue underline. */
function drawSectionHeader(doc, title, y, fonts) {
    doc.font(fonts.B).fontSize(14).fillColor(C_DARK);
    const titleH = doc.heightOfString(title, { width: CW });
    doc.text(title, MARGIN, y, { width: CW });
    const lineY = y + titleH + 3;
    doc.moveTo(MARGIN, lineY).lineTo(MARGIN + CW, lineY)
        .lineWidth(1.5).strokeColor(C_BLUE).stroke();
    return lineY + 6;
}
// ── Main PDF generation ────────────────────────────────────────────────────────
async function generatePDF(inspection, inspectionNumber, location, displayName, finalStatus, summaryComments, lang = "vi", errorItems = []) {
    const imageMap = await prefetchImages(inspection, errorItems);
    return new Promise((resolve, reject) => {
        var _a, _b, _c, _d, _e, _f;
        const chunks = [];
        const doc = new pdfkit_1.default({ margins: { top: 0, bottom: 0, left: 0, right: 0 }, size: "A4", autoFirstPage: false });
        const hasNoto = fs.existsSync(FONT_REGULAR) && fs.existsSync(FONT_BOLD);
        if (hasNoto) {
            doc.registerFont("R", FONT_REGULAR);
            doc.registerFont("B", FONT_BOLD);
        }
        const fonts = {
            R: hasNoto ? "R" : "Helvetica",
            B: hasNoto ? "B" : "Helvetica-Bold",
        };
        doc.on("data", (c) => chunks.push(c));
        doc.on("end", () => resolve(Buffer.concat(chunks)));
        doc.on("error", reject);
        // Cloud Functions run in UTC regardless of the deployed region, but this report is
        // always for a Vietnam-based inspection — render the timestamp in Vietnam local time
        // so it doesn't drift ~7 hours behind what the inspector actually saw.
        const now = new Date();
        const { date: dateStr, time: timeStr } = vnDateTimeParts(now);
        const dateTimeStr = `${dateStr} ${timeStr}`;
        const orderInfo = `Order: ${inspectionNumber}, Item: ${(_a = inspection.productName) !== null && _a !== void 0 ? _a : ""}`;
        let pageNum = 0;
        function newPage() {
            doc.addPage();
            pageNum++;
            drawFooter(doc, orderInfo, dateStr, pageNum, fonts, lang);
            return MARGIN;
        }
        // ── Page 1: Cover ─────────────────────────────────────────────────────────
        let y = newPage();
        // Small grey title
        doc.font(fonts.R).fontSize(11).fillColor(C_GRAY)
            .text(`${t(lang, "reportTitle")} ${inspectionNumber}`, MARGIN, y, { lineBreak: false });
        y += Math.ceil(11 * 1.2) + 4;
        // Bold subtitle: product code + product name (wraps to multiple lines for long names)
        const subtitle = `${(_b = inspection.productCode) !== null && _b !== void 0 ? _b : ""}: ${(_c = inspection.productName) !== null && _c !== void 0 ? _c : ""}`;
        doc.font(fonts.B).fontSize(20).fillColor(C_DARK);
        const subtitleH = doc.heightOfString(subtitle, { width: CW });
        doc.text(subtitle, MARGIN, y, { width: CW });
        y += subtitleH + 8;
        // Separator
        drawHLine(doc, y);
        y += 10;
        // Info table
        y = drawInfoTable(doc, [
            [t(lang, "inspector"), displayName || "N/A", t(lang, "inspectionDate"), dateTimeStr],
            [t(lang, "plannedSample"), `${(_d = inspection.aqlInspectionQuantity) !== null && _d !== void 0 ? _d : 0}/${(_e = inspection.inspectedQuantity) !== null && _e !== void 0 ? _e : 0}`,
                t(lang, "orderQty"), String((_f = inspection.orderQuantity) !== null && _f !== void 0 ? _f : 0)],
            [t(lang, "location"), location || "N/A", t(lang, "checklistName"), t(lang, "checklistNameValue")],
            [t(lang, "plannedDate"), dateStr, t(lang, "samplingMethod"), t(lang, "samplingMethodValue")],
            [t(lang, "supplierName"), inspection.factory || inspection.factoryName || "N/A", null, null],
        ], y, fonts);
        y += 8;
        // Inspector conclusion row (badge + optional notes)
        y = drawConclusionRow(doc, finalStatus, summaryComments, y, fonts, lang);
        y += 2;
        // Full-width status banner
        y = drawStatusBanner(doc, finalStatus, y, fonts, lang);
        y += 16;
        // SUMMARY heading
        doc.font(fonts.B).fontSize(14).fillColor(C_DARK)
            .text(t(lang, "summary"), MARGIN, y, { lineBreak: false });
        y += Math.ceil(14 * 1.2) + 8;
        // Checklist table + defect table
        const sections = Array.isArray(inspection.sections)
            ? inspection.sections : [];
        y = drawChecklistTable(doc, sections, imageMap, y, fonts, lang);
        y += 12;
        const { critical, major, minor } = countBySeverity(errorItems);
        y = drawDefectTable(doc, critical, major, minor, y, fonts);
        // ── Defects section: one entry per errorItems doc (title + severity + comments + images) ──
        if (errorItems.length > 0) {
            y += 16;
            if (y + 40 > CONTENT_MAX_Y) {
                y = newPage();
            }
            y = drawSectionHeader(doc, t(lang, "defectsSection"), y, fonts);
            y += 6;
            errorItems.forEach((item, di) => {
                const BADGE_H = 18;
                if (y + BADGE_H + 16 > CONTENT_MAX_Y) {
                    y = newPage();
                }
                // Severity badge + title + date, on one line
                const color = severityColor(item.severity);
                doc.font(fonts.B).fontSize(9);
                const badgeW = doc.widthOfString(item.severity) + 16;
                doc.roundedRect(MARGIN, y, badgeW, BADGE_H, 3).fillColor(color).fill();
                doc.fillColor(C_WHITE).text(item.severity, MARGIN + 8, y + 4, { lineBreak: false });
                const dateLabel = item.createdAt ? vnDateTimeParts(new Date(item.createdAt)).date : "";
                const dateW = 90;
                doc.font(fonts.B).fontSize(11).fillColor(C_DARK)
                    .text(defectTitle(item.defectType, lang), MARGIN + badgeW + 10, y + 3, { width: CW - badgeW - 10 - dateW, lineBreak: false });
                doc.font(fonts.R).fontSize(9).fillColor(C_GRAY)
                    .text(dateLabel, MARGIN + CW - dateW, y + 4, { width: dateW, align: "right", lineBreak: false });
                y += BADGE_H + 6;
                // Comments
                if (item.comments && item.comments.trim()) {
                    doc.font(fonts.R).fontSize(10).fillColor(C_MID);
                    const commentH = doc.heightOfString(item.comments, { width: CW });
                    if (y + commentH > CONTENT_MAX_Y) {
                        y = newPage();
                    }
                    doc.text(item.comments, MARGIN, y, { width: CW });
                    y += commentH + 6;
                }
                // Image grid — all imageURLs, 4 columns, no captions
                const bufs = item.imageURLs.map((u) => imageMap.get(u)).filter(Boolean);
                for (let rowStart = 0; rowStart < bufs.length; rowStart += IMGS_PER_ROW) {
                    if (y + IMG_H > CONTENT_MAX_Y) {
                        y = newPage();
                    }
                    bufs.slice(rowStart, rowStart + IMGS_PER_ROW).forEach((buf, col) => {
                        const imgX = MARGIN + col * (IMG_W + IMG_GAP);
                        try {
                            doc.image(buf, imgX, y, { fit: [IMG_W, IMG_H], align: "center", valign: "center" });
                            doc.lineWidth(0.5).rect(imgX, y, IMG_W, IMG_H).strokeColor(C_BORDER).stroke();
                        }
                        catch (e) {
                            console.warn(`Embed defect image failed: ${e}`);
                        }
                    });
                    y += IMG_H + IMG_GAP;
                }
                if (di < errorItems.length - 1)
                    y += 10;
            });
        }
        // ── Pages 2+: Sections ────────────────────────────────────────────────────
        const sorted = [...sections].sort((a, b) => { var _a, _b; return ((_a = a.order) !== null && _a !== void 0 ? _a : 0) - ((_b = b.order) !== null && _b !== void 0 ? _b : 0); });
        sorted.forEach((section, si) => {
            var _a;
            const fields = Array.isArray(section.fields) ? section.fields : [];
            const sectionHasImages = fields.some((f) => (Array.isArray(f.imageURLs) ? f.imageURLs : []).some((u) => imageMap.has(u)));
            // Force new page only when the section has photos (lots of content) or
            // when there is not enough room left for at least the section header + one field row.
            if (sectionHasImages || y + 60 > CONTENT_MAX_Y) {
                y = newPage();
            }
            else {
                y += si === 0 ? 24 : 20; // vertical gap between sections
            }
            y = drawSectionHeader(doc, `${si + 1}   ${(_a = section.title) !== null && _a !== void 0 ? _a : ""}`, y, fonts);
            y += 6;
            fields.forEach((field, fi) => {
                var _a, _b, _c, _d;
                const urls = Array.isArray(field.imageURLs) ? field.imageURLs : [];
                const bufs = urls.map((u) => imageMap.get(u)).filter(Boolean);
                const comment = (_a = field.comment) !== null && _a !== void 0 ? _a : "";
                doc.font(fonts.R).fontSize(10);
                const commentH = comment
                    ? doc.heightOfString(`${t(lang, "fieldComment")} ${comment}`, { width: CW }) + 6
                    : 0;
                const neededH = (bufs.length === 0 ? 30 : IMG_H + 40) + commentH;
                if (y + neededH > CONTENT_MAX_Y) {
                    y = newPage();
                }
                // Field heading
                doc.font(fonts.R).fontSize(11).fillColor(C_MID)
                    .text(`${si + 1}.${fi + 1}   ${(_b = field.label) !== null && _b !== void 0 ? _b : ""}`, MARGIN, y, { width: CW, lineBreak: false });
                y += Math.ceil(11 * 1.2) + 4;
                // Field-level remark, wrapped to full width with no truncation
                if (comment) {
                    doc.font(fonts.R).fontSize(10).fillColor(C_MID)
                        .text(`${t(lang, "fieldComment")} ${comment}`, MARGIN, y, { width: CW });
                    y += commentH;
                }
                // 4-column photo grid with optional per-image captions
                if (bufs.length > 0) {
                    const descriptions = (_c = field.imageDescriptions) !== null && _c !== void 0 ? _c : [];
                    const measurements = (_d = field.imageMeasurementsMM) !== null && _d !== void 0 ? _d : [];
                    const CAPTION_FONT_SIZE = 8;
                    const CAPTION_TOP_PAD = 3;
                    const MEASURE_FONT_SIZE = 8;
                    const MEASURE_LINE_H = MEASURE_FONT_SIZE * 1.4;
                    const MEASURE_TOP_PAD = 2;
                    const MEASURE_MAX_H = MEASURE_LINE_H;
                    // Process row by row so caption/measurement height is added once per row
                    for (let rowStart = 0; rowStart < bufs.length; rowStart += IMGS_PER_ROW) {
                        const rowBufs = bufs.slice(rowStart, rowStart + IMGS_PER_ROW);
                        const rowDescs = descriptions.slice(rowStart, rowStart + IMGS_PER_ROW);
                        const rowMeasurements = measurements.slice(rowStart, rowStart + IMGS_PER_ROW);
                        const hasCaption = rowDescs.some((d) => d && d.trim().length > 0);
                        const hasMeasurement = rowMeasurements.some((m) => parseMM(m) !== null);
                        // Full caption height for this row — no fixed line cap, so long captions
                        // wrap instead of being cut off with an ellipsis.
                        doc.font(fonts.R).fontSize(CAPTION_FONT_SIZE);
                        const rowCaptionH = hasCaption
                            ? Math.max(...rowDescs.map((d) => d && d.trim() ? doc.heightOfString(d.trim(), { width: IMG_W }) : 0))
                            : 0;
                        const rowH = IMG_H
                            + (hasCaption ? CAPTION_TOP_PAD + rowCaptionH : 0)
                            + (hasMeasurement ? MEASURE_TOP_PAD + MEASURE_MAX_H : 0);
                        if (y + rowH > CONTENT_MAX_Y) {
                            y = newPage();
                        }
                        rowBufs.forEach((buf, col) => {
                            const imgX = MARGIN + col * (IMG_W + IMG_GAP);
                            try {
                                doc.image(buf, imgX, y, { fit: [IMG_W, IMG_H], align: "center", valign: "center" });
                                doc.lineWidth(0.5).rect(imgX, y, IMG_W, IMG_H).strokeColor(C_BORDER).stroke();
                            }
                            catch (e) {
                                console.warn(`Embed image failed: ${e}`);
                            }
                        });
                        if (hasCaption) {
                            const captionY = y + IMG_H + CAPTION_TOP_PAD;
                            rowDescs.forEach((desc, col) => {
                                if (!desc || !desc.trim())
                                    return;
                                const capX = MARGIN + col * (IMG_W + IMG_GAP);
                                doc.font(fonts.R).fontSize(CAPTION_FONT_SIZE).fillColor(C_GRAY)
                                    .text(desc.trim(), capX, captionY, { width: IMG_W, lineBreak: true });
                            });
                        }
                        // Measurement (mm/inch) drawn on its own line below the caption
                        if (hasMeasurement) {
                            const measureY = y + IMG_H
                                + (hasCaption ? CAPTION_TOP_PAD + rowCaptionH : 0)
                                + MEASURE_TOP_PAD;
                            rowMeasurements.forEach((m, col) => {
                                const mm = parseMM(m);
                                if (mm === null)
                                    return;
                                const inch = (mm / 25.4).toFixed(2);
                                const mX = MARGIN + col * (IMG_W + IMG_GAP);
                                doc.font(fonts.R).fontSize(MEASURE_FONT_SIZE).fillColor(C_GRAY)
                                    .text(`${mm} mm (${inch} inch)`, mX, measureY, { width: IMG_W, height: MEASURE_MAX_H, lineBreak: false });
                            });
                        }
                        y += rowH + IMG_GAP;
                    }
                }
                y += 10;
            });
            y += 22;
        });
        doc.end();
    });
}
// ── Email HTML ─────────────────────────────────────────────────────────────────
function esc(s) {
    return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}
function buildEmailHTML(inspectionNumber, displayName, lang = "vi") {
    const body = t(lang, "emailBody")
        .replace("%n", esc(inspectionNumber));
    return `<!DOCTYPE html>
<html>
<head><meta charset="utf-8">
<style>
  body { font-family: Arial, sans-serif; background:#f5f5f5; padding:20px; }
  .card { background:#fff; border-radius:12px; padding:32px; max-width:600px; margin:0 auto; }
  .header { background:#1a73e8; color:#fff; border-radius:8px; padding:20px; text-align:center; margin-bottom:20px; }
  p { color:#555; font-size:14px; line-height:1.6; }
  .footer { color:#aaa; font-size:11px; text-align:center; margin-top:24px; }
</style>
</head>
<body>
  <div class="card">
    <div class="header"><h2 style="margin:0">${t(lang, "emailHeader")}${esc(inspectionNumber)}</h2></div>
    <p>${t(lang, "emailGreeting")}</p>
    <p>${body}</p>
    <p>${t(lang, "emailCta")}</p>
    <p>${t(lang, "emailClosing")}<br/><strong>${esc(displayName || "")}</strong></p>
    <div class="footer">${t(lang, "emailFooter")}</div>
  </div>
</body>
</html>`;
}
//# sourceMappingURL=index.js.map