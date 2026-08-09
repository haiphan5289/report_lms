import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import * as nodemailer from "nodemailer";
import PDFDocument from "pdfkit";
import * as path from "path";
import * as fs from "fs";
import * as https from "https";
import sharp from "sharp";

admin.initializeApp();

const gmailUser = defineSecret("GMAIL_USER");
const gmailPass = defineSecret("GMAIL_APP_PASSWORD");

const FONTS_DIR    = path.join(__dirname, "..", "fonts");
const FONT_REGULAR = path.join(FONTS_DIR, "NotoSans-Regular.ttf");
const FONT_BOLD    = path.join(FONTS_DIR, "NotoSans-Bold.ttf");

// ── Qarma-style layout — mirrors iOS PDFKitGeneratorService ───────────────────
const MARGIN        = 40;
const PAGE_H        = 841.89;
const CW            = 515.28;          // A4 content width = 595.28 - 2*40
const FOOTER_Y      = PAGE_H - 28;
const CONTENT_MAX_Y = PAGE_H - 46;

// 4-column photo grid
const IMGS_PER_ROW = 4;
const IMG_GAP      = 8;
const IMG_W        = (CW - IMG_GAP * (IMGS_PER_ROW - 1)) / IMGS_PER_ROW; // ≈122.8
const IMG_H        = IMG_W * 0.75;                                         // ≈92.1

const INFO_ROW_H  = 26;
const TABLE_ROW_H = 24;

// ── Colors ─────────────────────────────────────────────────────────────────────
const C_WHITE    = "#ffffff";
const C_DARK     = "#222222";
const C_MID      = "#404040";
const C_GRAY     = "#666666";
const C_FOOTER   = "#aaaaaa";
const C_BLUE     = "#3366cc";
const C_BORDER   = "#c8c8c8";
const C_LABEL_BG = "#f5f5f5";
const C_HDR_BG   = "#f2f2f2";
const C_CRITICAL = "#c62626";
const C_MAJOR    = "#e5990d";
const C_MINOR    = "#2473cc";
const C_GREEN    = "#33a14a";

// ── Interfaces ─────────────────────────────────────────────────────────────────
interface ReportTask {
  inspectionId:     string;
  inspectionNumber: string;
  recipientEmails:  string[];
  location:         string;
  requestedBy:      string;
  requestedByDisplayName?: string;
  finalStatus?:     string;   // "accepted" | "pending" | "rejected"
  summaryComments?: string;
  language?:        string;   // "vi" | "en"
}

// ── i18n ───────────────────────────────────────────────────────────────────────
type Lang = "vi" | "en";

const TRANSLATIONS: Record<Lang, Record<string, string>> = {
  vi: {
    reportTitle:          "Báo cáo kiểm tra, Hoàn tất:",
    inspector:            "Người kiểm tra",
    inspectionDate:       "Ngày kiểm tra",
    plannedSample:        "Mẫu KH/Thực tế",
    orderQty:             "SL đơn hàng",
    location:             "Vị trí",
    checklistName:        "Tên checklist",
    checklistNameValue:   "Danh sách kiểm tra cuối",
    plannedDate:          "Ngày kế hoạch",
    samplingMethod:       "Phương pháp",
    samplingMethodValue:  "Kiểm tra 100%",
    supplierName:         "Tên nhà máy",
    inspectorConclusion:  "Kết luận kiểm tra",
    statusBanner:         "Trạng thái:",
    summary:              "TÓM TẮT",
    summaryCommentsSection: "Tóm tắt nhận xét",
    checklistSection:     "Hạng mục kiểm tra",
    statusColumn:         "Trạng thái",
    accepted:             "ĐẠT",
    pending:              "CHỜ XEM XÉT",
    rejected:             "KHÔNG ĐẠT",
    footer:               "Báo cáo tạo bởi report_lms.",
    emailSubject:         "Báo cáo kiểm tra #",
    emailHeader:          "Báo cáo kiểm tra #",
    emailGreeting:        "Kính gửi,",
    emailBody:            "Đính kèm là báo cáo kiểm tra <strong>#%n</strong>.",
    emailCta:             "Vui lòng xem file PDF đính kèm để biết chi tiết.",
    emailClosing:         "Trân trọng,",
    emailFooter:          "Gửi tự động bởi LMS Report App",
    attachmentPrefix:     "Bao_cao_kiem_tra_",
    defectsSection:       "LỖI PHÁT HIỆN",
    defectTypeOther:      "Khác",
  },
  en: {
    reportTitle:          "Inspection report, Final:",
    inspector:            "Inspector",
    inspectionDate:       "Inspection Date",
    plannedSample:        "Planned Sample/Insp.",
    orderQty:             "Order Qty",
    location:             "Location",
    checklistName:        "Checklist Name",
    checklistNameValue:   "Final CheckList",
    plannedDate:          "Planned Date",
    samplingMethod:       "Sampling Method",
    samplingMethodValue:  "100% inspection",
    supplierName:         "Supplier Name",
    inspectorConclusion:  "Inspector Conclusion",
    statusBanner:         "Status:",
    summary:              "SUMMARY",
    summaryCommentsSection: "Summary Comments",
    checklistSection:     "Checklist Section",
    statusColumn:         "Status",
    accepted:             "ACCEPTED",
    pending:              "PENDING",
    rejected:             "REJECTED",
    footer:               "Report created with report_lms.",
    emailSubject:         "Inspection Report #",
    emailHeader:          "Inspection Report #",
    emailGreeting:        "Dear,",
    emailBody:            "Please find attached the inspection report <strong>#%n</strong>.",
    emailCta:             "Please review the attached PDF for details.",
    emailClosing:         "Best regards,",
    emailFooter:          "Sent automatically by LMS Report App",
    attachmentPrefix:     "Inspection_Report_",
    defectsSection:       "DEFECTS FOUND",
    defectTypeOther:      "Other",
  },
};

function t(lang: Lang, key: string): string {
  return TRANSLATIONS[lang]?.[key] ?? TRANSLATIONS["en"][key] ?? key;
}

/**
 * Mirrors `DefectType.name` in iOS `ErrorItem.swift` — Vietnamese-only, no English
 * variant exists on either side. Keep in sync manually if the iOS enum changes.
 */
const DEFECT_TYPE_NAMES: Record<string, string> = {
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
function defectTitle(code: string | undefined, lang: Lang): string {
  if (!code) return t(lang, "defectTypeOther");
  const name = DEFECT_TYPE_NAMES[code];
  return name ? `${code} - ${name}` : code;
}

/** Maps a `SavedErrorItem.severity` raw label (Vietnamese, written by the iOS app) to a defect-table color/column. */
function severityColor(severity: string): string {
  return severity === "Nghiêm trọng" ? C_CRITICAL : severity === "Nặng" ? C_MAJOR : C_MINOR;
}

/** Counts errorItems by severity for the CRITICAL/MAJOR/MINOR table — unrecognized/"Nhẹ" values count as minor. */
function countBySeverity(items: ErrorItemData[]): { critical: number; major: number; minor: number } {
  let critical = 0, major = 0, minor = 0;
  for (const item of items) {
    if (item.severity === "Nghiêm trọng") critical++;
    else if (item.severity === "Nặng") major++;
    else minor++;
  }
  return { critical, major, minor };
}

function isValidEmail(value: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(value);
}

/** Strip characters unsafe for a filename/email attachment name, turning dashes into spaces. */
function sanitizeFilenamePart(value: string): string {
  return value.trim().replace(/[\\/:*?"<>|]/g, "").replace(/-/g, " ").replace(/\s+/g, " ");
}

/** Formats a Date as Vietnam local (Asia/Ho_Chi_Minh) date + time, independent of the server's own timezone. */
function vnDateTimeParts(d: Date): { date: string; time: string } {
  const parts = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Ho_Chi_Minh",
    year: "numeric", month: "2-digit", day: "2-digit",
    hour: "2-digit", minute: "2-digit", hourCycle: "h23",
  }).formatToParts(d);
  const get = (type: string) => parts.find((p) => p.type === type)?.value ?? "";
  return {
    date: `${get("month")}/${get("day")}/${get("year")}`,
    time: `${get("hour")}:${get("minute")}`,
  };
}

/** Turn an email local-part into a display name, e.g. "hai.phan@chotot.vn" -> "Hai Phan". Non-email values (e.g. "unknown") pass through unchanged. */
function deriveDisplayName(value: string): string {
  const at = value.indexOf("@");
  if (at <= 0) return value;
  return value.slice(0, at)
    .split(".")
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(" ");
}

/** Parses a user-entered mm measurement string (comma or dot decimal separator). Returns null if empty/invalid. */
function parseMM(value?: string): number | null {
  if (!value || !value.trim()) return null;
  const n = parseFloat(value.replace(",", "."));
  return Number.isFinite(n) ? n : null;
}

interface InspectionField {
  id:                    string;
  label:                 string;
  value?:                string;
  imageURLs?:            string[];
  imageDescriptions?:    string[];
  imageMeasurementsMM?:  string[];
}

interface InspectionSection {
  id:     string;
  title:  string;
  order:  number;
  fields: InspectionField[];
}

/** Mirrors iOS `SavedErrorItem` (report_lms/Sources/Domain/Entities/ErrorItem.swift). */
interface ErrorItemData {
  id:          string;
  imageURLs:   string[];
  severity:    string;   // raw Vietnamese label: "Nhẹ" | "Nặng" | "Nghiêm trọng"
  defectType?: string;   // e.g. "SU-9"
  comments:    string;
  createdAt:   string;   // ISO8601, written by iOS SavedErrorItem.toFirestoreData()
}

type PdfDoc = InstanceType<typeof PDFDocument>;
type Fonts  = { R: string; B: string };

// ── Cloud Function ─────────────────────────────────────────────────────────────
export const processReportQueue = onDocumentCreated(
  {
    document:       "report_delivery_queue/{taskId}",
    secrets:        [gmailUser, gmailPass],
    region:         "asia-southeast1",
    timeoutSeconds: 120,
    memory:         "512MiB",
  },
  async (event) => {
    const taskId  = event.params.taskId;
    const db      = admin.firestore();
    const taskRef = db.collection("report_delivery_queue").doc(taskId);

    const data = event.data?.data() as ReportTask | undefined;
    if (!data) { console.error(`[${taskId}] No data in document`); return; }

    const {
      inspectionId, inspectionNumber, recipientEmails,
      location, requestedBy, requestedByDisplayName,
      finalStatus     = "pending",
      summaryComments = "",
      language        = "vi",
    } = data;
    const lang = (language === "en" ? "en" : "vi") as Lang;
    // Prefer the Profile-screen display name; fall back to deriving one from the email
    // for tasks queued before requestedByDisplayName existed.
    const displayName = requestedByDisplayName || (requestedBy ? deriveDisplayName(requestedBy) : "");

    await taskRef.update({ status: "processing" });
    console.log(`[${taskId}] Generating Qarma PDF for #${inspectionNumber}`);

    try {
      const snap = await db.collection("inspections").doc(inspectionId).get();
      const inspection = snap.data();
      if (!inspection) throw new Error(`Inspection ${inspectionId} not found`);

      const errorItemsSnap = await db
        .collection("inspections").doc(inspectionId)
        .collection("errorItems")
        .orderBy("createdAt", "desc")
        .get();
      const errorItems: ErrorItemData[] = errorItemsSnap.docs.map((d) => {
        const ed = d.data();
        return {
          id:         d.id,
          imageURLs:  Array.isArray(ed.imageURLs) ? ed.imageURLs : [],
          severity:   ed.severity ?? "Nhẹ",
          defectType: ed.defectType,
          comments:   ed.comments ?? "",
          createdAt:  ed.createdAt ?? "",
        };
      });

      const pdfBuffer = await generatePDF(
        inspection, inspectionNumber, location,
        displayName, finalStatus, summaryComments, lang, errorItems
      );
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

      await transporter.sendMail({
        from:    `"LMS Report" <${gmailUser.value()}>`,
        to:      recipientEmails.join(", "),
        ...(traceEmail ? { cc: traceEmail, replyTo: traceEmail } : {}),
        subject: `${t(lang, "emailSubject")}${inspectionNumber}`,
        html:    buildEmailHTML(inspectionNumber, displayName, lang),
        attachments: [{
          filename: `Final Report ${sanitizeFilenamePart(inspection.productName || inspectionNumber)}.pdf`,
          content:     pdfBuffer,
          contentType: "application/pdf",
        }],
      });

      console.log(`[${taskId}] Email sent to: ${recipientEmails.join(", ")}${traceEmail ? ` (cc: ${traceEmail})` : ""}`);
      await taskRef.update({ status: "sent", sentAt: admin.firestore.FieldValue.serverTimestamp() });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[${taskId}] Failed: ${message}`);
      try { await taskRef.update({ status: "failed", errorMessage: message }); } catch {}
    }
  }
);

// ── Image helpers ──────────────────────────────────────────────────────────────
async function compressImageBuffer(buf: Buffer): Promise<Buffer> {
  try {
    return await sharp(buf)
      .resize(800, 600, { fit: "inside", withoutEnlargement: true })
      .jpeg({ quality: 70 })
      .toBuffer();
  } catch { return buf; }
}

function downloadImageBuffer(url: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const req = https.get(url, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`Image fetch ${res.statusCode}: ${url}`)); return;
      }
      const chunks: Buffer[] = [];
      res.on("data", (c: Buffer) => chunks.push(c));
      res.on("end",  () => resolve(Buffer.concat(chunks)));
      res.on("error", reject);
    });
    req.on("error", reject);
    req.setTimeout(10000, () => { req.destroy(); reject(new Error("Image download timeout")); });
  });
}

/** Pre-fetch all field + defect images; process in batches of 5 to avoid memory spikes. */
async function prefetchImages(
  inspection: FirebaseFirestore.DocumentData,
  errorItems: ErrorItemData[] = []
): Promise<Map<string, Buffer>> {
  const map      = new Map<string, Buffer>();
  const sections = Array.isArray(inspection.sections)
    ? inspection.sections as InspectionSection[] : [];

  const urls: string[] = [];
  for (const section of sections) {
    for (const field of (section.fields ?? [])) {
      for (const url of (field.imageURLs ?? [])) {
        if (url && !map.has(url)) urls.push(url);
      }
    }
  }
  for (const item of errorItems) {
    for (const url of item.imageURLs) {
      if (url && !map.has(url)) urls.push(url);
    }
  }

  for (let i = 0; i < urls.length; i += 5) {
    await Promise.all(
      urls.slice(i, i + 5).map((url) =>
        downloadImageBuffer(url)
          .then(compressImageBuffer)
          .then((buf) => { map.set(url, buf); })
          .catch((e: Error) => { console.warn(`Skip image ${url}: ${e.message}`); })
      )
    );
  }
  return map;
}

// ── PDF drawing helpers ────────────────────────────────────────────────────────

function statusColor(s: string): string {
  return s === "accepted" ? C_GREEN : s === "rejected" ? C_CRITICAL : C_MAJOR;
}

function statusLabel(s: string, lang: Lang = "vi"): string {
  return s === "accepted" ? t(lang, "accepted")
       : s === "rejected" ? t(lang, "rejected")
       : t(lang, "pending");
}

/** Bordered cell with vertically-centred text. */
function drawCell(
  doc: PdfDoc, text: string,
  x: number, y: number, w: number, h: number,
  opts: { bg?: string; fg?: string; font?: string; size?: number; align?: "left" | "center" | "right" }
) {
  const { bg = C_WHITE, fg = C_DARK, font = "R", size = 10, align = "left" } = opts;
  const pad = 5;
  doc.lineWidth(0.5).rect(x, y, w, h).fillAndStroke(bg, C_BORDER);
  if (text) {
    const textY = y + Math.max(3, (h - size * 1.2) / 2);
    doc.font(font).fontSize(size).fillColor(fg)
      .text(text, x + pad, textY, { width: w - pad * 2, lineBreak: false, align });
  }
}

function drawHLine(doc: PdfDoc, y: number, color = "#cccccc", lw = 0.75) {
  doc.moveTo(MARGIN, y).lineTo(MARGIN + CW, y).lineWidth(lw).strokeColor(color).stroke();
}

/** Per-page footer: thin separator + left credit + right "Order:… page: N". */
function drawFooter(
  doc: PdfDoc, orderInfo: string, dateStr: string, pageNum: number, fonts: Fonts,
  lang: Lang = "vi"
) {
  drawHLine(doc, FOOTER_Y - 5, "#d0d0d0", 0.5);
  doc.font(fonts.R).fontSize(8).fillColor(C_FOOTER)
    .text(t(lang, "footer"), MARGIN, FOOTER_Y,
      { width: CW / 2, lineBreak: false });
  doc.font(fonts.R).fontSize(8).fillColor(C_FOOTER)
    .text(`${orderInfo}   ${dateStr}, page: ${pageNum}`,
      MARGIN + CW / 2, FOOTER_Y,
      { width: CW / 2, lineBreak: false, align: "right" });
}

/**
 * 4-column info table.
 * rows: [leftLabel, leftValue, rightLabel | null, rightValue | null]
 * When right columns are null, leftValue spans the remaining width.
 */
function drawInfoTable(
  doc: PdfDoc,
  rows: Array<[string, string, string | null, string | null]>,
  startY: number, fonts: Fonts
): number {
  const lw = CW * 0.22;
  const vw = CW * 0.28;
  let y = startY;

  for (const [ll, lv, rl, rv] of rows) {
    if (rl !== null && rv !== null) {
      drawCell(doc, ll, MARGIN,                y, lw, INFO_ROW_H, { bg: C_LABEL_BG, fg: C_GRAY, font: fonts.R });
      drawCell(doc, lv, MARGIN + lw,           y, vw, INFO_ROW_H, { bg: C_WHITE, fg: C_DARK, font: fonts.B });
      drawCell(doc, rl, MARGIN + lw + vw,      y, lw, INFO_ROW_H, { bg: C_LABEL_BG, fg: C_GRAY, font: fonts.R });
      drawCell(doc, rv, MARGIN + lw + vw + lw, y, vw, INFO_ROW_H, { bg: C_WHITE, fg: C_DARK, font: fonts.B });
    } else {
      drawCell(doc, ll, MARGIN,      y, lw,      INFO_ROW_H, { bg: C_LABEL_BG, fg: C_GRAY, font: fonts.R });
      drawCell(doc, lv, MARGIN + lw, y, CW - lw, INFO_ROW_H, { bg: C_WHITE, fg: C_DARK, font: fonts.B });
    }
    y += INFO_ROW_H;
  }
  return y;
}

/** "Inspector Conclusion" label + coloured badge + optional notes. */
function drawConclusionRow(
  doc: PdfDoc, finalStatus: string, summaryComments: string,
  y: number, fonts: Fonts, lang: Lang = "vi"
): number {
  doc.font(fonts.R).fontSize(10).fillColor(C_GRAY)
    .text(t(lang, "inspectorConclusion"), MARGIN, y + 6, { lineBreak: false });

  const label  = statusLabel(finalStatus, lang);
  const color  = statusColor(finalStatus);
  const badgeX = MARGIN + 140;
  doc.font(fonts.B).fontSize(9);
  const textW  = doc.widthOfString(label);
  const hPad = 8, vPad = 3;
  const bW = textW + hPad * 2;
  const bH = 9 * 1.2 + vPad * 2;

  doc.roundedRect(badgeX, y + 4, bW, bH, 2).fillColor(color).fill();
  doc.font(fonts.B).fontSize(9).fillColor(C_WHITE)
    .text(label, badgeX + hPad, y + 4 + vPad, { lineBreak: false });

  if (summaryComments) {
    const notesX = badgeX + bW + 10;
    doc.font(fonts.R).fontSize(9).fillColor(C_GRAY)
      .text(summaryComments, notesX, y + 6,
        { width: MARGIN + CW - notesX, lineBreak: false });
  }
  return y + INFO_ROW_H;
}

/** Full-width coloured status banner. */
function drawStatusBanner(
  doc: PdfDoc, finalStatus: string, y: number, fonts: Fonts, lang: Lang = "vi"
): number {
  const h = 26;
  doc.rect(MARGIN, y, CW, h).fillColor(statusColor(finalStatus)).fill();
  doc.font(fonts.R).fontSize(10).fillColor(C_WHITE)
    .text(t(lang, "statusBanner"), MARGIN + 10, y + 7, { lineBreak: false });
  doc.font(fonts.B).fontSize(10).fillColor(C_WHITE)
    .text(statusLabel(finalStatus, lang), MARGIN + 64, y + 7, { lineBreak: false });
  return y + h;
}

/** Checklist summary: section name | progress bar */
function drawChecklistTable(
  doc: PdfDoc, sections: InspectionSection[],
  imageMap: Map<string, Buffer>,
  startY: number, fonts: Fonts, lang: Lang = "vi"
): number {
  const nameW   = CW * 0.82;
  const statusW = CW - nameW;
  let y = startY;

  drawCell(doc, t(lang, "checklistSection"), MARGIN,         y, nameW,   TABLE_ROW_H,
    { bg: C_HDR_BG, fg: C_DARK, font: fonts.B });
  drawCell(doc, t(lang, "statusColumn"),     MARGIN + nameW, y, statusW, TABLE_ROW_H,
    { bg: C_HDR_BG, fg: C_DARK, font: fonts.B, align: "center" });
  y += TABLE_ROW_H;

  const sorted = [...sections].sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
  sorted.forEach((sec, i) => {
    const fields = sec.fields ?? [];
    const total = fields.length;
    const completed = fields.filter((f) =>
      (f.imageURLs ?? []).some((u) => imageMap.has(u))
    ).length;
    const progress = total > 0 ? completed / total : 0;

    const progressColor =
      progress === 0   ? "#9e9e9e" :
      progress < 0.5   ? "#ff9800" :
      progress < 1.0   ? "#2196f3" :
      C_GREEN;

    const rowBg = i % 2 === 0 ? C_WHITE : "#fafafa";
    drawCell(doc, `${i + 1}   ${sec.title}`, MARGIN, y, nameW, TABLE_ROW_H,
      { bg: rowBg, fg: C_DARK, font: fonts.R });

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
function drawDefectTable(
  doc: PdfDoc, critical: number, major: number, minor: number,
  startY: number, fonts: Fonts
): number {
  const descW = CW * 0.52;
  const colW  = (CW - descW) / 3;
  let y = startY;

  drawCell(doc, "",         MARGIN,                     y, descW, TABLE_ROW_H, { bg: C_HDR_BG, fg: C_DARK,     font: fonts.B });
  drawCell(doc, "CRITICAL", MARGIN + descW,             y, colW,  TABLE_ROW_H, { bg: C_HDR_BG, fg: C_CRITICAL, font: fonts.B, align: "center" });
  drawCell(doc, "MAJOR",    MARGIN + descW + colW,      y, colW,  TABLE_ROW_H, { bg: C_HDR_BG, fg: C_MAJOR,    font: fonts.B, align: "center" });
  drawCell(doc, "MINOR",    MARGIN + descW + colW * 2,  y, colW,  TABLE_ROW_H, { bg: C_HDR_BG, fg: C_MINOR,    font: fonts.B, align: "center" });
  y += TABLE_ROW_H;

  drawCell(doc, "TOTAL",          MARGIN,                    y, descW, TABLE_ROW_H, { bg: C_WHITE, fg: C_DARK,                             font: fonts.B });
  drawCell(doc, String(critical), MARGIN + descW,            y, colW,  TABLE_ROW_H, { bg: C_WHITE, fg: critical > 0 ? C_CRITICAL : C_DARK, font: fonts.B, align: "center" });
  drawCell(doc, String(major),    MARGIN + descW + colW,     y, colW,  TABLE_ROW_H, { bg: C_WHITE, fg: major    > 0 ? C_MAJOR    : C_DARK, font: fonts.B, align: "center" });
  drawCell(doc, String(minor),    MARGIN + descW + colW * 2, y, colW,  TABLE_ROW_H, { bg: C_WHITE, fg: minor    > 0 ? C_MINOR    : C_DARK, font: fonts.B, align: "center" });
  y += TABLE_ROW_H;
  return y;
}

/** Section heading: bold 14pt title + 1.5pt blue underline. */
function drawSectionHeader(doc: PdfDoc, title: string, y: number, fonts: Fonts): number {
  doc.font(fonts.B).fontSize(14).fillColor(C_DARK);
  const titleH = doc.heightOfString(title, { width: CW });
  doc.text(title, MARGIN, y, { width: CW });
  const lineY = y + titleH + 3;
  doc.moveTo(MARGIN, lineY).lineTo(MARGIN + CW, lineY)
    .lineWidth(1.5).strokeColor(C_BLUE).stroke();
  return lineY + 6;
}

// ── Main PDF generation ────────────────────────────────────────────────────────
async function generatePDF(
  inspection: FirebaseFirestore.DocumentData,
  inspectionNumber: string,
  location: string,
  displayName: string,
  finalStatus: string,
  summaryComments: string,
  lang: Lang = "vi",
  errorItems: ErrorItemData[] = []
): Promise<Buffer> {
  const imageMap = await prefetchImages(inspection, errorItems);

  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    const doc = new PDFDocument({ margins: { top: 0, bottom: 0, left: 0, right: 0 }, size: "A4", autoFirstPage: false });

    const hasNoto = fs.existsSync(FONT_REGULAR) && fs.existsSync(FONT_BOLD);
    if (hasNoto) { doc.registerFont("R", FONT_REGULAR); doc.registerFont("B", FONT_BOLD); }
    const fonts: Fonts = {
      R: hasNoto ? "R" : "Helvetica",
      B: hasNoto ? "B" : "Helvetica-Bold",
    };

    doc.on("data", (c: Buffer) => chunks.push(c));
    doc.on("end",  () => resolve(Buffer.concat(chunks)));
    doc.on("error", reject);

    // Cloud Functions run in UTC regardless of the deployed region, but this report is
    // always for a Vietnam-based inspection — render the timestamp in Vietnam local time
    // so it doesn't drift ~7 hours behind what the inspector actually saw.
    const now = new Date();
    const { date: dateStr, time: timeStr } = vnDateTimeParts(now);
    const dateTimeStr = `${dateStr} ${timeStr}`;
    const orderInfo   = `Order: ${inspectionNumber}, Item: ${inspection.productName ?? ""}`;
    let pageNum = 0;

    function newPage(): number {
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
    const subtitle = `${inspection.productCode ?? ""}: ${inspection.productName ?? ""}`;
    doc.font(fonts.B).fontSize(20).fillColor(C_DARK);
    const subtitleH = doc.heightOfString(subtitle, { width: CW });
    doc.text(subtitle, MARGIN, y, { width: CW });
    y += subtitleH + 8;

    // Separator
    drawHLine(doc, y);
    y += 10;

    // Info table
    y = drawInfoTable(doc, [
      [t(lang, "inspector"),     displayName || "N/A",  t(lang, "inspectionDate"), dateTimeStr],
      [t(lang, "plannedSample"), `${inspection.aqlInspectionQuantity ?? 0}/${inspection.inspectedQuantity ?? 0}`,
                                                         t(lang, "orderQty"),      String(inspection.orderQuantity ?? 0)],
      [t(lang, "location"),      location || "N/A",     t(lang, "checklistName"),  t(lang, "checklistNameValue")],
      [t(lang, "plannedDate"),   dateStr,               t(lang, "samplingMethod"), t(lang, "samplingMethodValue")],
      [t(lang, "supplierName"),  inspection.factory || inspection.factoryName || "N/A", null, null],
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
    const sections: InspectionSection[] = Array.isArray(inspection.sections)
      ? inspection.sections as InspectionSection[] : [];
    y = drawChecklistTable(doc, sections, imageMap, y, fonts, lang);
    y += 12;
    const { critical, major, minor } = countBySeverity(errorItems);
    y = drawDefectTable(doc, critical, major, minor, y, fonts);

    // Summary Comments section (hidden when empty) — sits just above the per-section
    // image pages that follow, mirrors iOS PDFKitGeneratorService's drawSummaryCommentsSection.
    if (summaryComments) {
      y += 16;
      if (y + 40 > CONTENT_MAX_Y) { y = newPage(); }
      doc.font(fonts.B).fontSize(14).fillColor(C_DARK)
        .text(t(lang, "summaryCommentsSection"), MARGIN, y, { lineBreak: false });
      y += Math.ceil(14 * 1.2) + 8;

      doc.font(fonts.R).fontSize(10).fillColor(C_MID);
      const commentsH = doc.heightOfString(summaryComments, { width: CW });
      doc.text(summaryComments, MARGIN, y, { width: CW });
      y += commentsH;
    }

    // ── Defects section: one entry per errorItems doc (title + severity + comments + images) ──
    if (errorItems.length > 0) {
      y += 16;
      if (y + 40 > CONTENT_MAX_Y) { y = newPage(); }
      y = drawSectionHeader(doc, t(lang, "defectsSection"), y, fonts);
      y += 6;

      errorItems.forEach((item, di) => {
        const BADGE_H = 18;
        if (y + BADGE_H + 16 > CONTENT_MAX_Y) { y = newPage(); }

        // Severity badge + title + date, on one line
        const color = severityColor(item.severity);
        doc.font(fonts.B).fontSize(9);
        const badgeW = doc.widthOfString(item.severity) + 16;
        doc.roundedRect(MARGIN, y, badgeW, BADGE_H, 3).fillColor(color).fill();
        doc.fillColor(C_WHITE).text(item.severity, MARGIN + 8, y + 4, { lineBreak: false });

        const dateLabel = item.createdAt ? vnDateTimeParts(new Date(item.createdAt)).date : "";
        const dateW = 90;
        doc.font(fonts.B).fontSize(11).fillColor(C_DARK)
          .text(defectTitle(item.defectType, lang), MARGIN + badgeW + 10, y + 3,
            { width: CW - badgeW - 10 - dateW, lineBreak: false });
        doc.font(fonts.R).fontSize(9).fillColor(C_GRAY)
          .text(dateLabel, MARGIN + CW - dateW, y + 4, { width: dateW, align: "right", lineBreak: false });
        y += BADGE_H + 6;

        // Comments
        if (item.comments && item.comments.trim()) {
          doc.font(fonts.R).fontSize(10).fillColor(C_MID);
          const commentH = doc.heightOfString(item.comments, { width: CW });
          if (y + commentH > CONTENT_MAX_Y) { y = newPage(); }
          doc.text(item.comments, MARGIN, y, { width: CW });
          y += commentH + 6;
        }

        // Image grid — all imageURLs, 4 columns, no captions
        const bufs = item.imageURLs.map((u) => imageMap.get(u)).filter(Boolean) as Buffer[];
        for (let rowStart = 0; rowStart < bufs.length; rowStart += IMGS_PER_ROW) {
          if (y + IMG_H > CONTENT_MAX_Y) { y = newPage(); }
          bufs.slice(rowStart, rowStart + IMGS_PER_ROW).forEach((buf, col) => {
            const imgX = MARGIN + col * (IMG_W + IMG_GAP);
            try {
              doc.image(buf, imgX, y, { fit: [IMG_W, IMG_H], align: "center", valign: "center" });
              doc.lineWidth(0.5).rect(imgX, y, IMG_W, IMG_H).strokeColor(C_BORDER).stroke();
            } catch (e) { console.warn(`Embed defect image failed: ${e}`); }
          });
          y += IMG_H + IMG_GAP;
        }

        if (di < errorItems.length - 1) y += 10;
      });
    }

    // ── Pages 2+: Sections ────────────────────────────────────────────────────
    const sorted = [...sections].sort((a, b) => (a.order ?? 0) - (b.order ?? 0));

    sorted.forEach((section, si) => {
      const fields: InspectionField[] = Array.isArray(section.fields) ? section.fields : [];
      const sectionHasImages = fields.some((f) =>
        (Array.isArray(f.imageURLs) ? f.imageURLs : []).some((u) => imageMap.has(u))
      );

      // Force new page only when the section has photos (lots of content) or
      // when there is not enough room left for at least the section header + one field row.
      if (sectionHasImages || y + 60 > CONTENT_MAX_Y) {
        y = newPage();
      } else {
        y += si === 0 ? 24 : 20; // vertical gap between sections
      }

      y = drawSectionHeader(doc, `${si + 1}   ${section.title ?? ""}`, y, fonts);
      y += 6;

      fields.forEach((field, fi) => {
        const urls    = Array.isArray(field.imageURLs) ? field.imageURLs : [];
        const bufs    = urls.map((u) => imageMap.get(u)).filter(Boolean) as Buffer[];
        const neededH = bufs.length === 0 ? 30 : IMG_H + 40;

        if (y + neededH > CONTENT_MAX_Y) { y = newPage(); }

        // Field heading
        doc.font(fonts.R).fontSize(11).fillColor(C_MID)
          .text(`${si + 1}.${fi + 1}   ${field.label ?? ""}`, MARGIN, y,
            { width: CW, lineBreak: false });
        y += Math.ceil(11 * 1.2) + 4;

        // 4-column photo grid with optional per-image captions
        if (bufs.length > 0) {
          const descriptions  = field.imageDescriptions ?? [];
          const measurements  = field.imageMeasurementsMM ?? [];
          const CAPTION_FONT_SIZE = 8;
          const CAPTION_TOP_PAD   = 3;
          const MEASURE_FONT_SIZE = 8;
          const MEASURE_LINE_H    = MEASURE_FONT_SIZE * 1.4;
          const MEASURE_TOP_PAD   = 2;
          const MEASURE_MAX_H     = MEASURE_LINE_H;

          // Process row by row so caption/measurement height is added once per row
          for (let rowStart = 0; rowStart < bufs.length; rowStart += IMGS_PER_ROW) {
            const rowBufs  = bufs.slice(rowStart, rowStart + IMGS_PER_ROW);
            const rowDescs = descriptions.slice(rowStart, rowStart + IMGS_PER_ROW);
            const rowMeasurements = measurements.slice(rowStart, rowStart + IMGS_PER_ROW);
            const hasCaption = rowDescs.some((d) => d && d.trim().length > 0);
            const hasMeasurement = rowMeasurements.some((m) => parseMM(m) !== null);

            // Full caption height for this row — no fixed line cap, so long captions
            // wrap instead of being cut off with an ellipsis.
            doc.font(fonts.R).fontSize(CAPTION_FONT_SIZE);
            const rowCaptionH = hasCaption
              ? Math.max(...rowDescs.map((d) =>
                  d && d.trim() ? doc.heightOfString(d.trim(), { width: IMG_W }) : 0
                ))
              : 0;

            const rowH = IMG_H
              + (hasCaption ? CAPTION_TOP_PAD + rowCaptionH : 0)
              + (hasMeasurement ? MEASURE_TOP_PAD + MEASURE_MAX_H : 0);

            if (y + rowH > CONTENT_MAX_Y) { y = newPage(); }

            rowBufs.forEach((buf, col) => {
              const imgX = MARGIN + col * (IMG_W + IMG_GAP);
              try {
                doc.image(buf, imgX, y, { fit: [IMG_W, IMG_H], align: "center", valign: "center" });
                doc.lineWidth(0.5).rect(imgX, y, IMG_W, IMG_H).strokeColor(C_BORDER).stroke();
              } catch (e) { console.warn(`Embed image failed: ${e}`); }
            });

            if (hasCaption) {
              const captionY = y + IMG_H + CAPTION_TOP_PAD;
              rowDescs.forEach((desc, col) => {
                if (!desc || !desc.trim()) return;
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
                if (mm === null) return;
                const inch = (mm / 25.4).toFixed(2);
                const mX = MARGIN + col * (IMG_W + IMG_GAP);
                doc.font(fonts.R).fontSize(MEASURE_FONT_SIZE).fillColor(C_GRAY)
                  .text(`${mm} mm (${inch} inch)`, mX, measureY,
                    { width: IMG_W, height: MEASURE_MAX_H, lineBreak: false });
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
function esc(s: string): string {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function buildEmailHTML(
  inspectionNumber: string, displayName: string, lang: Lang = "vi"
): string {
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
