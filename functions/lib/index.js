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
        checklistSection: "Hạng mục kiểm tra",
        statusColumn: "Trạng thái",
        accepted: "ĐẠT",
        pending: "CHỜ XEM XÉT",
        rejected: "KHÔNG ĐẠT",
        footer: "Báo cáo tạo bởi report_lms.",
        emailSubject: "Báo cáo kiểm tra #",
        emailHeader: "Báo cáo kiểm tra #",
        emailGreeting: "Kính gửi,",
        emailBody: "Đính kèm là báo cáo kiểm tra <strong>#%n</strong> cho <strong>%c</strong>.",
        emailCta: "Vui lòng xem file PDF đính kèm để biết chi tiết.",
        emailClosing: "Trân trọng,",
        emailFooter: "Gửi tự động bởi LMS Report App",
        attachmentPrefix: "Bao_cao_kiem_tra_",
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
        checklistSection: "Checklist Section",
        statusColumn: "Status",
        accepted: "ACCEPTED",
        pending: "PENDING",
        rejected: "REJECTED",
        footer: "Report created with report_lms.",
        emailSubject: "Inspection Report #",
        emailHeader: "Inspection Report #",
        emailGreeting: "Dear,",
        emailBody: "Please find attached the inspection report <strong>#%n</strong> for <strong>%c</strong>.",
        emailCta: "Please review the attached PDF for details.",
        emailClosing: "Best regards,",
        emailFooter: "Sent automatically by LMS Report App",
        attachmentPrefix: "Inspection_Report_",
    },
};
function t(lang, key) {
    var _a, _b, _c;
    return (_c = (_b = (_a = TRANSLATIONS[lang]) === null || _a === void 0 ? void 0 : _a[key]) !== null && _b !== void 0 ? _b : TRANSLATIONS["en"][key]) !== null && _c !== void 0 ? _c : key;
}
// ── Cloud Function ─────────────────────────────────────────────────────────────
exports.processReportQueue = (0, firestore_1.onDocumentCreated)({
    document: "report_delivery_queue/{taskId}",
    secrets: [gmailUser, gmailPass],
    region: "asia-southeast1",
    timeoutSeconds: 120,
    memory: "512MiB",
}, async (event) => {
    var _a, _b;
    const taskId = event.params.taskId;
    const db = admin.firestore();
    const taskRef = db.collection("report_delivery_queue").doc(taskId);
    const data = (_a = event.data) === null || _a === void 0 ? void 0 : _a.data();
    if (!data) {
        console.error(`[${taskId}] No data in document`);
        return;
    }
    const { inspectionId, inspectionNumber, recipientEmails, location, requestedBy, finalStatus = "pending", summaryComments = "", language = "vi", } = data;
    const lang = (language === "en" ? "en" : "vi");
    await taskRef.update({ status: "processing" });
    console.log(`[${taskId}] Generating Qarma PDF for #${inspectionNumber}`);
    try {
        const snap = await db.collection("inspections").doc(inspectionId).get();
        const inspection = snap.data();
        if (!inspection)
            throw new Error(`Inspection ${inspectionId} not found`);
        const pdfBuffer = await generatePDF(inspection, inspectionNumber, location, requestedBy !== null && requestedBy !== void 0 ? requestedBy : "", finalStatus, summaryComments, lang);
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
        await transporter.sendMail({
            from: `"LMS Report" <${gmailUser.value()}>`,
            to: recipientEmails.join(", "),
            subject: `${t(lang, "emailSubject")}${inspectionNumber}`,
            html: buildEmailHTML(inspectionNumber, (_b = inspection.companyName) !== null && _b !== void 0 ? _b : "", requestedBy, lang),
            attachments: [{
                    filename: `${t(lang, "attachmentPrefix")}${inspectionNumber}.pdf`,
                    content: pdfBuffer,
                    contentType: "application/pdf",
                }],
        });
        console.log(`[${taskId}] Email sent to: ${recipientEmails.join(", ")}`);
        await taskRef.update({ status: "sent", sentAt: admin.firestore.FieldValue.serverTimestamp() });
    }
    catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        console.error(`[${taskId}] Failed: ${message}`);
        try {
            await taskRef.update({ status: "failed", errorMessage: message });
        }
        catch (_c) { }
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
/** Pre-fetch all field images; process in batches of 5 to avoid memory spikes. */
async function prefetchImages(inspection) {
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
    if (summaryComments) {
        const notesX = badgeX + bW + 10;
        doc.font(fonts.R).fontSize(9).fillColor(C_GRAY)
            .text(summaryComments, notesX, y + 6, { width: MARGIN + CW - notesX, lineBreak: false });
    }
    return y + INFO_ROW_H;
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
    doc.font(fonts.B).fontSize(14).fillColor(C_DARK)
        .text(title, MARGIN, y, { width: CW, lineBreak: false });
    const lineY = y + 14 * 1.2 + 3;
    doc.moveTo(MARGIN, lineY).lineTo(MARGIN + CW, lineY)
        .lineWidth(1.5).strokeColor(C_BLUE).stroke();
    return lineY + 6;
}
// ── Main PDF generation ────────────────────────────────────────────────────────
async function generatePDF(inspection, inspectionNumber, location, requestedBy, finalStatus, summaryComments, lang = "vi") {
    const imageMap = await prefetchImages(inspection);
    return new Promise((resolve, reject) => {
        var _a, _b, _c, _d, _e, _f, _g;
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
        const now = new Date();
        const fmtDate = (d) => `${(d.getMonth() + 1).toString().padStart(2, "0")}/${d.getDate().toString().padStart(2, "0")}/${d.getFullYear()}`;
        const dateStr = fmtDate(now);
        const dateTimeStr = `${dateStr} ${now.getHours().toString().padStart(2, "0")}:${now.getMinutes().toString().padStart(2, "0")}`;
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
        // Bold subtitle: order number + product name
        doc.font(fonts.B).fontSize(20).fillColor(C_DARK)
            .text(`${inspectionNumber}: ${(_b = inspection.productName) !== null && _b !== void 0 ? _b : ""}`, MARGIN, y, { width: CW, lineBreak: false });
        y += Math.ceil(20 * 1.2) + 8;
        // Separator
        drawHLine(doc, y);
        y += 10;
        // Info table
        y = drawInfoTable(doc, [
            [t(lang, "inspector"), requestedBy || "N/A", t(lang, "inspectionDate"), dateTimeStr],
            [t(lang, "plannedSample"), `${(_c = inspection.aqlInspectionQuantity) !== null && _c !== void 0 ? _c : 0}/${(_d = inspection.inspectedQuantity) !== null && _d !== void 0 ? _d : 0}`,
                t(lang, "orderQty"), String((_e = inspection.orderQuantity) !== null && _e !== void 0 ? _e : 0)],
            [t(lang, "location"), location || "N/A", t(lang, "checklistName"), t(lang, "checklistNameValue")],
            [t(lang, "plannedDate"), dateStr, t(lang, "samplingMethod"), t(lang, "samplingMethodValue")],
            [t(lang, "supplierName"), (_g = (_f = inspection.factory) !== null && _f !== void 0 ? _f : inspection.factoryName) !== null && _g !== void 0 ? _g : "N/A", null, null],
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
        y = drawDefectTable(doc, 0, 0, 0, y, fonts); // counts are not stored server-side
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
                var _a, _b;
                const urls = Array.isArray(field.imageURLs) ? field.imageURLs : [];
                const bufs = urls.map((u) => imageMap.get(u)).filter(Boolean);
                const neededH = bufs.length === 0 ? 30 : IMG_H + 40;
                if (y + neededH > CONTENT_MAX_Y) {
                    y = newPage();
                }
                // Field heading
                doc.font(fonts.R).fontSize(11).fillColor(C_MID)
                    .text(`${si + 1}.${fi + 1}   ${(_a = field.label) !== null && _a !== void 0 ? _a : ""}`, MARGIN, y, { width: CW, lineBreak: false });
                y += Math.ceil(11 * 1.2) + 4;
                // 4-column photo grid with optional per-image captions
                if (bufs.length > 0) {
                    const descriptions = (_b = field.imageDescriptions) !== null && _b !== void 0 ? _b : [];
                    const CAPTION_FONT_SIZE = 8;
                    const CAPTION_LINE_H = CAPTION_FONT_SIZE * 1.4;
                    const CAPTION_TOP_PAD = 3;
                    const CAPTION_MAX_H = CAPTION_LINE_H * 2 + 2;
                    // Process row by row so caption height is added once per row
                    for (let rowStart = 0; rowStart < bufs.length; rowStart += IMGS_PER_ROW) {
                        const rowBufs = bufs.slice(rowStart, rowStart + IMGS_PER_ROW);
                        const rowDescs = descriptions.slice(rowStart, rowStart + IMGS_PER_ROW);
                        const hasCaption = rowDescs.some((d) => d && d.trim().length > 0);
                        const rowH = IMG_H + (hasCaption ? CAPTION_TOP_PAD + CAPTION_MAX_H : 0);
                        if (y + rowH > CONTENT_MAX_Y) {
                            y = newPage();
                        }
                        rowBufs.forEach((buf, col) => {
                            const imgX = MARGIN + col * (IMG_W + IMG_GAP);
                            try {
                                doc.image(buf, imgX, y, { width: IMG_W, height: IMG_H });
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
                                    .text(desc.trim(), capX, captionY, { width: IMG_W, height: CAPTION_MAX_H, lineBreak: true, ellipsis: true });
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
function buildEmailHTML(inspectionNumber, companyName, requestedBy, lang = "vi") {
    const body = t(lang, "emailBody")
        .replace("%n", esc(inspectionNumber))
        .replace("%c", esc(companyName));
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
    <p>${t(lang, "emailClosing")}<br/><strong>${esc(requestedBy !== null && requestedBy !== void 0 ? requestedBy : "")}</strong></p>
    <div class="footer">${t(lang, "emailFooter")}</div>
  </div>
</body>
</html>`;
}
//# sourceMappingURL=index.js.map