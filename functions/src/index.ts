import * as admin from "firebase-admin";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import * as nodemailer from "nodemailer";
import PDFDocument from "pdfkit";
import * as path from "path";
import * as fs from "fs";
import * as https from "https";
import * as http from "http";
import sharp from "sharp";

admin.initializeApp();

const gmailUser = defineSecret("GMAIL_USER");
const gmailPass = defineSecret("GMAIL_APP_PASSWORD");

// NotoSans fonts for Vietnamese text support
const FONTS_DIR = path.join(__dirname, "..", "fonts");
const FONT_REGULAR = path.join(FONTS_DIR, "NotoSans-Regular.ttf");
const FONT_BOLD = path.join(FONTS_DIR, "NotoSans-Bold.ttf");

// Layout constants — match iOS PDFKitGeneratorService
const MARGIN = 40;
const PAGE_W = 515.28; // A4 content width (595.28 - 2*40)

// Design colors — same as iOS
const C_BLUE = "#1a73e8";
const C_WHITE = "#ffffff";
const C_DARK = "#333333";
const C_MID = "#555555";
const C_GRAY = "#666666";
const C_FOOTER = "#aaaaaa";
const C_CRITICAL = "#c62828";
const C_MAJOR = "#e65100";
const C_MINOR = "#f9a825";

interface ReportTask {
  inspectionId: string;
  inspectionNumber: string;
  recipientEmails: string[];
  location: string;
  requestedBy: string;
}

interface InspectionField {
  id: string;
  label: string;
  value?: string;
}

interface InspectionSection {
  id: string;
  title: string;
  order: number;
  fields: InspectionField[];
}

export const processReportQueue = onDocumentCreated(
  {
    document: "report_delivery_queue/{taskId}",
    secrets: [gmailUser, gmailPass],
    region: "asia-southeast1",
    timeoutSeconds: 120,
    memory: "512MiB",
  },
  async (event) => {
    const taskId = event.params.taskId;
    const db = admin.firestore();
    const taskRef = db.collection("report_delivery_queue").doc(taskId);

    const data = event.data?.data() as ReportTask | undefined;
    if (!data) {
      console.error(`[${taskId}] No data in document`);
      return;
    }

    const { inspectionId, inspectionNumber, recipientEmails, location, requestedBy } = data;
    await taskRef.update({ status: "processing" });
    console.log(`[${taskId}] Generating PDF for #${inspectionNumber}`);

    try {
      const snap = await db.collection("inspections").doc(inspectionId).get();
      const inspection = snap.data();
      if (!inspection) throw new Error(`Inspection ${inspectionId} not found`);

      const pdfBuffer = await generatePDF(inspection, inspectionNumber, location, requestedBy ?? "");
      console.log(`[${taskId}] PDF generated: ${pdfBuffer.length} bytes`);

      const transporter = nodemailer.createTransport({
        service: "gmail",
        auth: {
          user: gmailUser.value(),
          pass: gmailPass.value(),
        },
      });

      await transporter.sendMail({
        from: `"LMS Report" <${gmailUser.value()}>`,
        to: recipientEmails.join(", "),
        subject: `Báo cáo kiểm tra #${inspectionNumber}`,
        html: buildEmailHTML(inspectionNumber, inspection.companyName ?? "", requestedBy),
        attachments: [
          {
            filename: `Bao_cao_kiem_tra_${inspectionNumber}.pdf`,
            content: pdfBuffer,
            contentType: "application/pdf",
          },
        ],
      });

      console.log(`[${taskId}] Email sent to: ${recipientEmails.join(", ")}`);
      await taskRef.update({
        status: "sent",
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`[${taskId}] Failed: ${message}`);
      await taskRef.update({ status: "failed", errorMessage: message });
    }
  }
);

// ---------------------------------------------------------------------------
// Image download helper
// ---------------------------------------------------------------------------

/** Resize + compress to JPEG 70% max 800px — keeps PDF well under Gmail 25 MB limit. */
async function compressImageBuffer(buf: Buffer): Promise<Buffer> {
  try {
    return await sharp(buf)
      .resize(800, 600, { fit: "inside", withoutEnlargement: true })
      .jpeg({ quality: 70 })
      .toBuffer();
  } catch {
    return buf;
  }
}

function downloadImageBuffer(url: string): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    const mod = url.startsWith("https") ? https : http;
    const req = (mod as typeof https).get(url, (res) => {
      if (res.statusCode !== 200) {
        reject(new Error(`Image fetch ${res.statusCode}: ${url}`));
        return;
      }
      const chunks: Buffer[] = [];
      res.on("data", (c: Buffer) => chunks.push(c));
      res.on("end", () => resolve(Buffer.concat(chunks)));
      res.on("error", reject);
    });
    req.on("error", reject);
    req.setTimeout(10000, () => { req.destroy(); reject(new Error("Image download timeout")); });
  });
}

/** Pre-fetch all imageURLs from inspection sections into a url→buffer map. */
async function prefetchImages(
  inspection: FirebaseFirestore.DocumentData
): Promise<Map<string, Buffer>> {
  const map = new Map<string, Buffer>();
  const sections: InspectionSection[] = Array.isArray(inspection.sections)
    ? inspection.sections : [];

  const tasks: Promise<void>[] = [];
  for (const section of sections) {
    for (const field of (section.fields ?? [])) {
      const urls: string[] = Array.isArray((field as any).imageURLs)
        ? (field as any).imageURLs : [];
      for (const url of urls) {
        if (url && !map.has(url)) {
          tasks.push(
            downloadImageBuffer(url)
              .then((buf) => compressImageBuffer(buf))
              .then((buf) => { map.set(url, buf); })
              .catch((e) => { console.warn(`Skip image ${url}: ${e.message}`); })
          );
        }
      }
    }
  }
  await Promise.all(tasks);
  return map;
}

// ---------------------------------------------------------------------------
// PDF Generation — layout mirrors iOS PDFKitGeneratorService
// ---------------------------------------------------------------------------

async function generatePDF(
  inspection: FirebaseFirestore.DocumentData,
  inspectionNumber: string,
  location: string,
  requestedBy: string
): Promise<Buffer> {
  // Pre-download all field images before opening the PDF stream
  const imageMap = await prefetchImages(inspection);

  return new Promise((resolve, reject) => {
    const chunks: Buffer[] = [];
    const doc = new PDFDocument({ margin: MARGIN, size: "A4" });

    // Register NotoSans for Vietnamese — fall back to Helvetica if fonts missing
    const hasNoto = fs.existsSync(FONT_REGULAR) && fs.existsSync(FONT_BOLD);
    if (hasNoto) {
      doc.registerFont("R", FONT_REGULAR);
      doc.registerFont("B", FONT_BOLD);
    }
    const R = hasNoto ? "R" : "Helvetica";
    const B = hasNoto ? "B" : "Helvetica-Bold";

    doc.on("data", (chunk: Buffer) => chunks.push(chunk));
    doc.on("end", () => resolve(Buffer.concat(chunks)));
    doc.on("error", reject);

    const X = MARGIN;
    const W = PAGE_W;
    let y = MARGIN;

    // ── 1. Header field rows — mirrors iOS drawHeaderFields ─────────────────
    const now = new Date();
    const fmt = (d: Date) =>
      `${d.getDate().toString().padStart(2, "0")}/` +
      `${(d.getMonth() + 1).toString().padStart(2, "0")}/` +
      `${d.getFullYear()}`;
    const todayStr = fmt(now);

    const headerRows: [string, string, string, string][] = [
      ["Người kiểm tra:", requestedBy || "N/A",
       "Ngày kiểm tra:",  todayStr],
      ["Số lượng mẫu:",   String(inspection.inspectedQuantity ?? 0),
       "Số lượng đơn hàng:", String(inspection.orderQuantity ?? 0)],
      ["Vị trí:",         location || "N/A",
       "Tên biểu mẫu:",   inspection.inspectionType ?? "Final CheckList"],
      ["Ngày dự kiến:",   todayStr,
       "Phương pháp lấy mẫu:", "100% inspection"],
    ];

    const HALF = W / 2;
    const LABEL_W = HALF * 0.48;
    const VAL_W   = HALF * 0.50;
    const ROW_H_HDR = 20;

    headerRows.forEach(([lLbl, lVal, rLbl, rVal]) => {
      const ty = y + 2;
      doc.fillColor(C_GRAY).font(R).fontSize(10)
        .text(lLbl, X, ty, { width: LABEL_W, lineBreak: false });
      doc.fillColor(C_DARK).font(B).fontSize(10)
        .text(lVal, X + LABEL_W + 2, ty, { width: VAL_W, lineBreak: false });
      // dashes
      doc.fillColor("#cccccc").font(R).fontSize(10)
        .text("---------", X + LABEL_W + VAL_W + 4, ty, { lineBreak: false });
      // right side
      doc.fillColor(C_GRAY).font(R).fontSize(10)
        .text(rLbl, X + HALF + 20, ty, { width: LABEL_W, lineBreak: false });
      doc.fillColor(C_DARK).font(B).fontSize(10)
        .text(rVal, X + HALF + 20 + LABEL_W + 2, ty, { width: VAL_W, lineBreak: false });
      y += ROW_H_HDR;
    });

    // Factory name — full width row
    const factoryLabel = "Tên nhà máy:";
    const factoryValue = inspection.factory ?? inspection.factoryName ?? "N/A";
    doc.fillColor(C_GRAY).font(R).fontSize(10)
      .text(factoryLabel, X, y + 2, { width: LABEL_W, lineBreak: false });
    doc.fillColor(C_DARK).font(B).fontSize(10)
      .text(factoryValue, X + LABEL_W + 2, y + 2, { width: W - LABEL_W - 2, lineBreak: false });
    y += ROW_H_HDR;

    // Gray separator line
    y += 6;
    doc.moveTo(X, y).lineTo(X + W, y).lineWidth(1).strokeColor("#cccccc").stroke();
    y += 14;

    // ── 2. Report title ──────────────────────────────────────────────────────
    doc.fillColor(C_DARK).font(B).fontSize(22)
      .text(`Báo cáo kiểm tra #${inspectionNumber}`, X, y, {
        width: W,
        lineBreak: false,
      });
    y += 32;

    // Date subtitle
    const dateTimeStr = `${now.getDate().toString().padStart(2, "0")}/` +
      `${(now.getMonth() + 1).toString().padStart(2, "0")}/` +
      `${now.getFullYear()} ` +
      `${now.getHours().toString().padStart(2, "0")}:` +
      `${now.getMinutes().toString().padStart(2, "0")}`;
    doc.fillColor(C_GRAY).font(R).fontSize(10)
      .text(`Ngày tạo: ${dateTimeStr}`, X, y, { lineBreak: false });
    y += 22;

    // ── 3. Defect summary table ──────────────────────────────────────────────
    doc.fillColor(C_DARK).font(B).fontSize(12)
      .text("Tóm tắt lỗi", X, y, { lineBreak: false });
    y += 20;

    const CW = W / 4;
    const defectHeaders = ["", "CRITICAL", "MAJOR", "MINOR"];
    const defectHColors = [C_DARK, C_CRITICAL, C_MAJOR, C_MINOR];

    defectHeaders.forEach((h, i) => {
      doc.rect(X + i * CW, y, CW, 24).fillAndStroke("#f5f5f5", "#e0e0e0");
      doc.fillColor(defectHColors[i]).font(B).fontSize(9)
        .text(h, X + i * CW + 4, y + 7,
          { width: CW - 8, align: "center", lineBreak: false });
    });
    y += 24;

    const critical = inspection.criticalCount ?? 0;
    const major    = inspection.majorCount ?? 0;
    const minor    = inspection.minorCount ?? 0;
    const defectVals    = ["TOTAL", String(critical), String(major), String(minor)];
    const defectVColors = [C_DARK, C_CRITICAL, C_MAJOR, C_MINOR];

    defectVals.forEach((v, i) => {
      doc.rect(X + i * CW, y, CW, 28).fillAndStroke(C_WHITE, "#e0e0e0");
      doc.fillColor(defectVColors[i]).font(i === 0 ? B : R).fontSize(11)
        .text(v, X + i * CW + 4, y + 8,
          { width: CW - 8, align: "center", lineBreak: false });
    });
    y += 42;

    // ── 4. Inspection sections ───────────────────────────────────────────────
    const IMG_GAP  = 12;
    const IMG_W    = (W - IMG_GAP) / 2;
    const IMG_H    = IMG_W * 0.75; // 4:3

    const sections: InspectionSection[] = Array.isArray(inspection.sections)
      ? inspection.sections : [];

    sections
      .sort((a, b) => (a.order ?? 0) - (b.order ?? 0))
      .forEach((section) => {
        if (y > doc.page.height - 120) { doc.addPage(); y = MARGIN; }

        // Section title + blue underline
        doc.fillColor(C_DARK).font(B).fontSize(14)
          .text(section.title ?? "", X, y, { width: W, lineBreak: false });
        y += 20;
        doc.moveTo(X, y).lineTo(X + W, y).lineWidth(2).strokeColor(C_BLUE).stroke();
        y += 10;

        const fields: InspectionField[] = Array.isArray(section.fields)
          ? section.fields : [];

        fields.forEach((field) => {
          const urls: string[] = Array.isArray((field as any).imageURLs)
            ? (field as any).imageURLs : [];
          const hasImages = urls.length > 0 && urls.some((u) => imageMap.has(u));

          if (!hasImages) return; // skip fields without captured images

          if (y > doc.page.height - IMG_H - 60) { doc.addPage(); y = MARGIN; }

          // Field label
          doc.fillColor(C_MID).font(R).fontSize(12)
            .text(field.label ?? "", X, y, { width: W, lineBreak: false });
          y += 18;

          // Images — 2 per row
          let col = 0;
          let rowStartY = y;
          for (const url of urls) {
            const imgBuf = imageMap.get(url);
            if (!imgBuf) continue;

            if (y + IMG_H > doc.page.height - MARGIN) {
              doc.addPage(); y = MARGIN; rowStartY = y; col = 0;
            }

            const imgX = X + col * (IMG_W + IMG_GAP);
            try {
              doc.image(imgBuf, imgX, y, { width: IMG_W, height: IMG_H });
              // Light border
              doc.rect(imgX, y, IMG_W, IMG_H).lineWidth(0.5).strokeColor("#cccccc").stroke();
            } catch (e) {
              console.warn(`Embed image failed: ${e}`);
            }

            col++;
            if (col >= 2) {
              col = 0;
              y += IMG_H + IMG_GAP;
              rowStartY = y;
            }
          }
          if (col > 0) { y = rowStartY + IMG_H + IMG_GAP; }
          y += 8;
        });

        y += 14;
      });

    // ── 5. Footer ─────────────────────────────────────────────────────────────
    doc.fillColor(C_FOOTER).font(R).fontSize(8.5)
      .text(
        "Báo cáo được tạo bởi report_lms  •  © 2026",
        X,
        doc.page.height - 34,
        { width: W, align: "center", lineBreak: false }
      );

    doc.end();
  });
}

// ---------------------------------------------------------------------------
// Email HTML body
// ---------------------------------------------------------------------------

function buildEmailHTML(
  inspectionNumber: string,
  companyName: string,
  requestedBy: string
): string {
  return `
<!DOCTYPE html>
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
    <div class="header"><h2 style="margin:0">Báo cáo kiểm tra #${inspectionNumber}</h2></div>
    <p>Kính gửi,</p>
    <p>Đính kèm là báo cáo kiểm tra <strong>#${inspectionNumber}</strong> cho <strong>${companyName}</strong>.</p>
    <p>Vui lòng xem file PDF đính kèm để biết chi tiết.</p>
    <p>Trân trọng,<br/><strong>${requestedBy}</strong></p>
    <div class="footer">Gửi tự động bởi LMS Report App</div>
  </div>
</body>
</html>`.trim();
}
