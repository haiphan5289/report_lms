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
  finalStatus?:     string;   // "accepted" | "pending" | "rejected"
  summaryComments?: string;
}

interface InspectionField {
  id:         string;
  label:      string;
  value?:     string;
  imageURLs?: string[];
}

interface InspectionSection {
  id:     string;
  title:  string;
  order:  number;
  fields: InspectionField[];
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
      location, requestedBy,
      finalStatus     = "pending",
      summaryComments = "",
    } = data;

    await taskRef.update({ status: "processing" });
    console.log(`[${taskId}] Generating Qarma PDF for #${inspectionNumber}`);

    try {
      const snap = await db.collection("inspections").doc(inspectionId).get();
      const inspection = snap.data();
      if (!inspection) throw new Error(`Inspection ${inspectionId} not found`);

      const pdfBuffer = await generatePDF(
        inspection, inspectionNumber, location,
        requestedBy ?? "", finalStatus, summaryComments
      );
      console.log(`[${taskId}] PDF generated: ${pdfBuffer.length} bytes`);

      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: { user: gmailUser.value(), pass: gmailPass.value() },
      });

      await transporter.sendMail({
        from:    `"LMS Report" <${gmailUser.value()}>`,
        to:      recipientEmails.join(", "),
        subject: `Báo cáo kiểm tra #${inspectionNumber}`,
        html:    buildEmailHTML(inspectionNumber, inspection.companyName ?? "", requestedBy),
        attachments: [{
          filename:    `Bao_cao_kiem_tra_${inspectionNumber}.pdf`,
          content:     pdfBuffer,
          contentType: "application/pdf",
        }],
      });

      console.log(`[${taskId}] Email sent to: ${recipientEmails.join(", ")}`);
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

/** Pre-fetch all field images; process in batches of 5 to avoid memory spikes. */
async function prefetchImages(
  inspection: FirebaseFirestore.DocumentData
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

function statusLabel(s: string): string {
  return s === "accepted" ? "ACCEPTED" : s === "rejected" ? "REJECTED" : "PENDING";
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
  doc: PdfDoc, orderInfo: string, dateStr: string, pageNum: number, fonts: Fonts
) {
  drawHLine(doc, FOOTER_Y - 5, "#d0d0d0", 0.5);
  doc.font(fonts.R).fontSize(8).fillColor(C_FOOTER)
    .text("Report created with report_lms.", MARGIN, FOOTER_Y,
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
  y: number, fonts: Fonts
): number {
  doc.font(fonts.R).fontSize(10).fillColor(C_GRAY)
    .text("Inspector Conclusion", MARGIN, y + 6, { lineBreak: false });

  const label  = statusLabel(finalStatus);
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
  doc: PdfDoc, finalStatus: string, y: number, fonts: Fonts
): number {
  const h = 26;
  doc.rect(MARGIN, y, CW, h).fillColor(statusColor(finalStatus)).fill();
  doc.font(fonts.R).fontSize(10).fillColor(C_WHITE)
    .text("Status:", MARGIN + 10, y + 7, { lineBreak: false });
  doc.font(fonts.B).fontSize(10).fillColor(C_WHITE)
    .text(statusLabel(finalStatus), MARGIN + 64, y + 7, { lineBreak: false });
  return y + h;
}

/** Checklist summary: section name | ✓ or — */
function drawChecklistTable(
  doc: PdfDoc, sections: InspectionSection[],
  imageMap: Map<string, Buffer>,
  startY: number, fonts: Fonts
): number {
  const nameW   = CW * 0.82;
  const statusW = CW - nameW;
  let y = startY;

  drawCell(doc, "Checklist Section", MARGIN,          y, nameW,   TABLE_ROW_H,
    { bg: C_HDR_BG, fg: C_DARK, font: fonts.B });
  drawCell(doc, "Status",            MARGIN + nameW,  y, statusW, TABLE_ROW_H,
    { bg: C_HDR_BG, fg: C_DARK, font: fonts.B, align: "center" });
  y += TABLE_ROW_H;

  const sorted = [...sections].sort((a, b) => (a.order ?? 0) - (b.order ?? 0));
  sorted.forEach((sec, i) => {
    const hasPhotos = (sec.fields ?? []).some((f) =>
      (f.imageURLs ?? []).some((u) => imageMap.has(u))
    );
    const rowBg = i % 2 === 0 ? C_WHITE : "#fafafa";
    drawCell(doc, `${i + 1}   ${sec.title}`, MARGIN,         y, nameW,   TABLE_ROW_H,
      { bg: rowBg, fg: C_DARK, font: fonts.R });
    drawCell(doc, hasPhotos ? "✓" : "—",      MARGIN + nameW, y, statusW, TABLE_ROW_H,
      { bg: rowBg, fg: hasPhotos ? C_GREEN : C_FOOTER, font: fonts.B, align: "center" });
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
  doc.font(fonts.B).fontSize(14).fillColor(C_DARK)
    .text(title, MARGIN, y, { width: CW, lineBreak: false });
  const lineY = y + 14 * 1.2 + 3;
  doc.moveTo(MARGIN, lineY).lineTo(MARGIN + CW, lineY)
    .lineWidth(1.5).strokeColor(C_BLUE).stroke();
  return lineY + 6;
}

// ── Main PDF generation ────────────────────────────────────────────────────────
async function generatePDF(
  inspection: FirebaseFirestore.DocumentData,
  inspectionNumber: string,
  location: string,
  requestedBy: string,
  finalStatus: string,
  summaryComments: string
): Promise<Buffer> {
  const imageMap = await prefetchImages(inspection);

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

    const now = new Date();
    const fmtDate = (d: Date) =>
      `${(d.getMonth() + 1).toString().padStart(2, "0")}/${d.getDate().toString().padStart(2, "0")}/${d.getFullYear()}`;
    const dateStr     = fmtDate(now);
    const dateTimeStr = `${dateStr} ${now.getHours().toString().padStart(2, "0")}:${now.getMinutes().toString().padStart(2, "0")}`;
    const orderInfo   = `Order: ${inspectionNumber}, Item: ${inspection.productName ?? ""}`;
    let pageNum = 0;

    function newPage(): number {
      doc.addPage();
      pageNum++;
      drawFooter(doc, orderInfo, dateStr, pageNum, fonts);
      return MARGIN;
    }

    // ── Page 1: Cover ─────────────────────────────────────────────────────────
    let y = newPage();

    // Small grey title
    doc.font(fonts.R).fontSize(11).fillColor(C_GRAY)
      .text(`Inspection report, Final: ${inspectionNumber}`, MARGIN, y, { lineBreak: false });
    y += Math.ceil(11 * 1.2) + 4;

    // Bold subtitle: order number + product name
    doc.font(fonts.B).fontSize(20).fillColor(C_DARK)
      .text(`${inspectionNumber}: ${inspection.productName ?? ""}`, MARGIN, y,
        { width: CW, lineBreak: false });
    y += Math.ceil(20 * 1.2) + 8;

    // Separator
    drawHLine(doc, y);
    y += 10;

    // Info table
    y = drawInfoTable(doc, [
      ["Inspector",            requestedBy || "N/A",  "Inspection Date",  dateTimeStr],
      ["Planned Sample/Insp.", `${inspection.aqlInspectionQuantity ?? 0}/${inspection.inspectedQuantity ?? 0}`,
                                                       "Order Qty",         String(inspection.orderQuantity ?? 0)],
      ["Location",             location || "N/A",     "Checklist Name",   "Final CheckList"],
      ["Planned Date",         dateStr,               "Sampling Method",  "100% inspection"],
      ["Supplier Name",        inspection.factory ?? inspection.factoryName ?? "N/A", null, null],
    ], y, fonts);
    y += 8;

    // Inspector conclusion row (badge + optional notes)
    y = drawConclusionRow(doc, finalStatus, summaryComments, y, fonts);
    y += 2;

    // Full-width status banner
    y = drawStatusBanner(doc, finalStatus, y, fonts);
    y += 16;

    // SUMMARY heading
    doc.font(fonts.B).fontSize(14).fillColor(C_DARK)
      .text("SUMMARY", MARGIN, y, { lineBreak: false });
    y += Math.ceil(14 * 1.2) + 8;

    // Checklist table + defect table
    const sections: InspectionSection[] = Array.isArray(inspection.sections)
      ? inspection.sections as InspectionSection[] : [];
    y = drawChecklistTable(doc, sections, imageMap, y, fonts);
    y += 12;
    y = drawDefectTable(doc, 0, 0, 0, y, fonts);  // counts are not stored server-side

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

        // 4-column photo grid
        if (bufs.length > 0) {
          let col = 0;
          for (const buf of bufs) {
            if (col === 0 && y + IMG_H > CONTENT_MAX_Y) { y = newPage(); }
            const imgX = MARGIN + col * (IMG_W + IMG_GAP);
            try {
              doc.image(buf, imgX, y, { width: IMG_W, height: IMG_H });
              doc.lineWidth(0.5).rect(imgX, y, IMG_W, IMG_H).strokeColor(C_BORDER).stroke();
            } catch (e) { console.warn(`Embed image failed: ${e}`); }
            col++;
            if (col >= IMGS_PER_ROW) { col = 0; y += IMG_H + IMG_GAP; }
          }
          if (col > 0) { y += IMG_H + IMG_GAP; }
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
  inspectionNumber: string, companyName: string, requestedBy: string
): string {
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
    <div class="header"><h2 style="margin:0">Báo cáo kiểm tra #${esc(inspectionNumber)}</h2></div>
    <p>Kính gửi,</p>
    <p>Đính kèm là báo cáo kiểm tra <strong>#${esc(inspectionNumber)}</strong> cho <strong>${esc(companyName)}</strong>.</p>
    <p>Vui lòng xem file PDF đính kèm để biết chi tiết.</p>
    <p>Trân trọng,<br/><strong>${esc(requestedBy)}</strong></p>
    <div class="footer">Gửi tự động bởi LMS Report App</div>
  </div>
</body>
</html>`;
}
