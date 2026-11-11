// 레슨계약서 v2 P5: 완료된 계약서 PDF 등록과 회원 열람 링크.
//
// - attachPersonalContractPdf(callable): 앱이 올린 PDF를 서버가 읽어 형식·크기·SHA-256을 기록하고,
//   열람 링크 토큰을 발급한다(토큰 원문은 응답으로만 주고 해시만 저장, 유효 90일, 재발급하면 이전 링크 무효).
// - viewPersonalContract(HTTPS): 링크 토큰·만료·계약 상태를 확인하고 PDF를 내려 준 뒤 열람 기록을 남긴다.
// - verifyPersonalContract(HTTPS): PDF 맨 아래 QR·문서확인번호로 서버에 기록된 원본인지 확인한다.
import {createHash, randomBytes, timingSafeEqual} from "crypto";
import {FieldValue, Timestamp} from "firebase-admin/firestore";
import * as functions from "firebase-functions/v1";

import {
  CONTRACTS,
  Ctx,
  Data,
  Db,
  allowOnly,
  loadOwnedContract,
  objectData,
  requireContractId,
  requireProfile,
  requireUid,
  translated,
} from "./personal_contracts.js";

export const LINK_TTL_DAYS = 90;
export const MAX_PDF_BYTES = 10 * 1024 * 1024;
const LINK_TOKEN_PATTERN = /^[A-Za-z0-9_-]{43}$/u;
const CONTRACT_ID_PATTERN = /^pc_[a-f0-9]{32}$/u;

// PDF 파일 저장소. 실제로는 Storage 버킷이고, 테스트에서는 메모리로 바꿔 쓴다.
export interface PdfStore {
  // 파일을 읽는다. 없으면 null, [MAX_PDF_BYTES]보다 크면 [PdfTooLargeError].
  read(path: string): Promise<Buffer | null>;
}

export class PdfTooLargeError extends Error {}

export function pdfStoragePath(
  trainerId: string,
  contractId: string,
  version: number,
): string {
  return `personal_contracts/${trainerId}/${contractId}/contract_v${version}.pdf`;
}

// `%PDF-` 머리와 파일 끝 근처의 `%%EOF`가 있는 PDF인지.
export function isPdfBuffer(bytes: Buffer): boolean {
  if (bytes.length < 16) return false;
  if (bytes.subarray(0, 5).toString("latin1") !== "%PDF-") return false;
  const tail = bytes.subarray(Math.max(0, bytes.length - 1024));
  return tail.toString("latin1").includes("%%EOF");
}

export function sha256Hex(bytes: Buffer | string): string {
  return createHash("sha256").update(bytes).digest("hex");
}

// 256비트 랜덤 토큰(43자, URL에 안전).
export function newLinkToken(): string {
  return randomBytes(32).toString("base64url");
}

export function hashLinkToken(token: string): string {
  return sha256Hex(token);
}

// 저장된 해시와 토큰이 같은지(시간 차 공격을 막기 위해 같은 길이로 비교).
export function tokenMatches(token: string, storedHash: unknown): boolean {
  if (typeof storedHash !== "string" || !/^[a-f0-9]{64}$/u.test(storedHash)) {
    return false;
  }
  const a = Buffer.from(hashLinkToken(token), "hex");
  const b = Buffer.from(storedHash, "hex");
  return a.length === b.length && timingSafeEqual(a, b);
}

export function viewUrl(
  projectId: string,
  contractId: string,
  token: string,
): string {
  const host = `https://asia-northeast3-${projectId}.cloudfunctions.net`;
  return `${host}/viewPersonalContract?c=${contractId}&t=${token}`;
}

// 링크 미리보기를 만드는 봇인지. 미리보기 요청은 PDF는 주되 열람으로 세지 않는다.
// 카카오톡 앱 안에서 회원이 직접 여는 경우(UA에 KAKAOTALK)는 봇이 아니다.
export function isPreviewBot(userAgent: string | undefined): boolean {
  if (!userAgent) return false;
  const pattern = new RegExp(
    "(kakaotalk-scrap|facebookexternalhit|facebot|twitterbot|slackbot|" +
    "linkedinbot|telegrambot|discordbot|googlebot|bingbot|applebot|yeti|" +
    "whatsapp/)",
    "iu",
  );
  return pattern.test(userAgent);
}

function contractVersion(contract: Data): number {
  const version = Number(contract.version ?? 1);
  return Number.isInteger(version) && version >= 1 ? version : 1;
}

// ---- attachPersonalContractPdf ----
export function createAttachPersonalContractPdfHandler(
  db: Db,
  store: PdfStore,
  options: {now?: () => Date; projectId?: string} = {},
) {
  const now = options.now ?? (() => new Date());
  const projectId =
    options.projectId ?? process.env.GCLOUD_PROJECT ?? "unknown-project";
  return async (raw: unknown, ctx: Ctx) => {
    const uid = requireUid(ctx);
    const data = objectData(raw);
    allowOnly(data, ["contractId", "issueLink"]);
    const contractId = requireContractId(data);
    if (data.issueLink != null && typeof data.issueLink !== "boolean") {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "issueLink_invalid",
      );
    }
    const issueLink = data.issueLink !== false;
    try {
      const contractRef = db.collection(CONTRACTS).doc(contractId);
      const profileRef = db.collection("trainer_profiles").doc(uid);
      const [profileSnap, contractSnap] = await Promise.all([
        profileRef.get(),
        contractRef.get(),
      ]);
      requireProfile(uid, profileSnap, ctx);
      const contract = loadOwnedContract(uid, contractSnap);
      if (contract.status !== "completed") {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "contract_not_completed",
        );
      }
      const version = contractVersion(contract);
      const path = pdfStoragePath(uid, contractId, version);

      // PDF는 처음 등록할 때만 읽고 해시를 계산한다(이미 등록됐으면 그 기록을 그대로 쓴다).
      const delivery = (contract.delivery ?? {}) as Data;
      let pdfHash = typeof delivery.pdfHash === "string" ? delivery.pdfHash : "";
      let pdfSize = Number(delivery.pdfSize ?? 0);
      if (!pdfHash) {
        let bytes: Buffer | null;
        try {
          bytes = await store.read(path);
        } catch (error) {
          if (error instanceof PdfTooLargeError) {
            throw new functions.https.HttpsError(
              "invalid-argument",
              "pdf_too_large",
            );
          }
          throw error;
        }
        if (bytes == null) {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "pdf_not_uploaded",
          );
        }
        if (bytes.length > MAX_PDF_BYTES) {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "pdf_too_large",
          );
        }
        if (!isPdfBuffer(bytes)) {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "pdf_invalid",
          );
        }
        pdfHash = sha256Hex(bytes);
        pdfSize = bytes.length;
      }

      const token = issueLink ? newLinkToken() : null;
      const expiresAt = new Date(
        now().getTime() + LINK_TTL_DAYS * 24 * 60 * 60 * 1000,
      );
      const result = await db.runTransaction(async (transaction) => {
        const snap = await transaction.get(contractRef);
        const current = loadOwnedContract(uid, snap);
        if (current.status !== "completed") {
          throw new functions.https.HttpsError(
            "failed-precondition",
            "contract_not_completed",
          );
        }
        const currentDelivery = (current.delivery ?? {}) as Data;
        const next: Data = {...currentDelivery};
        const serverNow = FieldValue.serverTimestamp();
        // 먼저 등록된 기록이 있으면(동시에 두 번 요청한 경우) 그 값을 지킨다.
        if (typeof currentDelivery.pdfHash === "string" &&
            currentDelivery.pdfHash.length > 0) {
          pdfHash = currentDelivery.pdfHash;
          pdfSize = Number(currentDelivery.pdfSize ?? pdfSize);
        } else {
          next.pdfPath = path;
          next.pdfHash = pdfHash;
          next.pdfSize = pdfSize;
          next.pdfAttachedAt = serverNow;
          transaction.create(contractRef.collection("events").doc(), {
            type: "pdf_attached",
            at: serverNow,
            actorRole: "trainer",
            contentHash: String(current.contentHash ?? ""),
            payload: {pdfHash, pdfSize, path},
          });
        }
        if (token != null) {
          next.linkTokenHash = hashLinkToken(token);
          next.linkCreatedAt = serverNow;
          next.linkExpiresAt = Timestamp.fromDate(expiresAt);
          transaction.create(contractRef.collection("events").doc(), {
            type: "link_created",
            at: serverNow,
            actorRole: "trainer",
            contentHash: String(current.contentHash ?? ""),
            payload: {expiresAt: expiresAt.toISOString()},
          });
        }
        transaction.update(contractRef, {delivery: next, updatedAt: serverNow});
        return {pdfHash, pdfSize};
      });

      return {
        contractId,
        version,
        pdfHash: result.pdfHash,
        pdfSize: result.pdfSize,
        ...(token == null ?
          {} :
          {
            linkToken: token,
            linkExpiresAtMs: expiresAt.getTime(),
            viewUrl: viewUrl(projectId, contractId, token),
          }),
      };
    } catch (error) {
      return translated(error, "attach_pdf");
    }
  };
}

// ---- viewPersonalContract (HTTPS) ----
type Req = functions.https.Request;
type Res = functions.Response;

function sendPage(res: Res, status: number, title: string, message: string) {
  res.status(status);
  res.set({
    "Content-Type": "text/html; charset=utf-8",
    "Content-Security-Policy":
      "default-src 'none'; style-src 'unsafe-inline'",
  });
  res.send(
    "<!doctype html><html lang=\"ko\"><head><meta charset=\"utf-8\">" +
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">" +
    `<title>${title}</title><style>body{font-family:sans-serif;padding:32px;` +
    "line-height:1.6;color:#111}</style></head><body>" +
    `<h2>${title}</h2><p>${message}</p></body></html>`,
  );
}

function notFound(res: Res) {
  sendPage(
    res,
    404,
    "계약서를 찾을 수 없어요",
    "링크가 올바른지 확인하거나 강사에게 새 링크를 요청해 주세요.",
  );
}

export function createViewPersonalContractHandler(
  db: Db,
  store: PdfStore,
  options: {now?: () => Date} = {},
) {
  const now = options.now ?? (() => new Date());
  return async (req: Req, res: Res) => {
    res.set({
      "Cache-Control": "private, no-store",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
      "X-Robots-Tag": "noindex, nofollow",
    });
    if (req.method !== "GET" && req.method !== "HEAD") {
      res.set("Allow", "GET, HEAD");
      res.status(405).send("");
      return;
    }
    const contractId = typeof req.query.c === "string" ? req.query.c : "";
    const token = typeof req.query.t === "string" ? req.query.t : "";
    // 형식이 맞지 않으면 DB를 읽지 않고 같은 404로 답한다(계약 ID 추측 방지).
    if (!CONTRACT_ID_PATTERN.test(contractId) ||
        !LINK_TOKEN_PATTERN.test(token)) {
      notFound(res);
      return;
    }
    try {
      const contractRef = db.collection(CONTRACTS).doc(contractId);
      const snap = await contractRef.get();
      const contract = snap.data();
      const delivery = (contract?.delivery ?? {}) as Data;
      if (contract?.status === "voided" &&
          tokenMatches(token, delivery.linkTokenHash)) {
        sendPage(
          res,
          410,
          "파기된 계약서예요",
          "이 계약서는 파기되어 더 이상 효력이 없어요. 궁금한 점은 강사에게 문의해 주세요.",
        );
        return;
      }
      if (!contract ||
          (contract.status !== "completed" &&
           contract.status !== "terminated" &&
           contract.status !== "superseded") ||
          typeof delivery.pdfPath !== "string" ||
          !tokenMatches(token, delivery.linkTokenHash)) {
        notFound(res);
        return;
      }
      const expiresAt = delivery.linkExpiresAt instanceof Timestamp ?
        delivery.linkExpiresAt.toDate() :
        null;
      if (!expiresAt || expiresAt.getTime() <= now().getTime()) {
        sendPage(
          res,
          410,
          "링크 기간이 지났어요",
          "계약서 링크의 유효기간이 지났어요. 강사에게 새 링크를 요청해 주세요.",
        );
        return;
      }
      const expectedPath = pdfStoragePath(
        String(contract.trainerId),
        contractId,
        contractVersion(contract),
      );
      if (delivery.pdfPath !== expectedPath) {
        notFound(res);
        return;
      }
      const bytes = await store.read(expectedPath);
      if (bytes == null) {
        notFound(res);
        return;
      }
      // 등록할 때 기록한 해시와 같은 파일인지 확인한다(바뀐 파일은 내주지 않는다).
      if (sha256Hex(bytes) !== delivery.pdfHash) {
        functions.logger.error("[MTF_PERSONAL_CONTRACT] pdf_hash_mismatch", {
          contractId,
        });
        sendPage(
          res,
          500,
          "계약서를 열 수 없어요",
          "잠시 후 다시 시도하거나 강사에게 문의해 주세요.",
        );
        return;
      }

      if (req.method === "GET" && !isPreviewBot(req.get("user-agent"))) {
        try {
          await db.runTransaction(async (transaction) => {
            const fresh = await transaction.get(contractRef);
            const current = (fresh.data()?.delivery ?? {}) as Data;
            const serverNow = FieldValue.serverTimestamp();
            transaction.update(contractRef, {
              delivery: {
                ...current,
                viewCount: Number(current.viewCount ?? 0) + 1,
                firstViewedAt: current.firstViewedAt ?? serverNow,
                lastViewedAt: serverNow,
              },
            });
            transaction.create(contractRef.collection("events").doc(), {
              type: "viewed",
              at: serverNow,
              actorRole: "member",
              contentHash: String(contract.contentHash ?? ""),
              payload: {},
            });
          });
        } catch (error) {
          // 열람 기록에 실패해도 회원이 계약서를 보는 것은 막지 않는다.
          functions.logger.error("[MTF_PERSONAL_CONTRACT] view_record_failed", {
            errorName: error instanceof Error ? error.name : "UnknownError",
          });
        }
      }

      res.status(200);
      res.set({
        "Content-Type": "application/pdf",
        "Content-Disposition": "inline; filename=\"lesson-contract.pdf\"",
        "Content-Length": String(bytes.length),
      });
      if (req.method === "HEAD") {
        res.end();
      } else {
        res.end(bytes);
      }
    } catch (error) {
      functions.logger.error("[MTF_PERSONAL_CONTRACT] view failed", {
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
      sendPage(
        res,
        500,
        "계약서를 열 수 없어요",
        "잠시 후 다시 시도하거나 강사에게 문의해 주세요.",
      );
    }
  };
}

// ---- verifyPersonalContract (HTTPS) ----
const VERIFY_CODE_PATTERN = /^[A-Fa-f0-9]{16}$/u;
const FILE_HASH_PATTERN = /^[a-f0-9]{64}$/u;

// 문서확인번호: 계약 내용 해시 앞 16자(대문자). 앱 PDF에 찍히는 값과 같은 규칙이다.
export function contractVerificationCode(contentHash: string): string {
  return contentHash.slice(0, 16).toUpperCase();
}

function escapeHtml(text: string): string {
  return text
    .replace(/&/gu, "&amp;")
    .replace(/</gu, "&lt;")
    .replace(/>/gu, "&gt;")
    .replace(/"/gu, "&quot;");
}

function formatKst(date: Date): string {
  const kst = new Date(date.getTime() + 9 * 60 * 60 * 1000);
  const two = (value: number) => String(value).padStart(2, "0");
  return `${kst.getUTCFullYear()}-${two(kst.getUTCMonth() + 1)}-` +
    `${two(kst.getUTCDate())} ${two(kst.getUTCHours())}:` +
    `${two(kst.getUTCMinutes())}`;
}

// 확인 화면. 회원 이름·연락처 같은 개인정보는 싣지 않고 계약번호·완료 시각·상태만 보여 준다.
// 아래 스크립트는 고른 PDF 파일의 SHA-256을 브라우저에서 계산해 서버 기록과 같은지 묻는다
// (파일 자체는 서버로 보내지 않는다).
function verifyPage(params: {
  contractId: string;
  code: string;
  contractNo: string;
  completedAt: string;
  statusLabel: string;
  codeText: string;
}): string {
  const rows = [
    ["계약번호", params.contractNo],
    ["계약 완료", params.completedAt || "-"],
    ["상태", params.statusLabel],
    ["문서확인번호", params.codeText],
  ].map(([k, v]) =>
    `<tr><th>${escapeHtml(k)}</th><td>${escapeHtml(v)}</td></tr>`,
  ).join("");
  const endpoint = `?c=${params.contractId}&k=${params.code}`;
  return "<!doctype html><html lang=\"ko\"><head><meta charset=\"utf-8\">" +
    "<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">" +
    "<title>계약서 진위 확인</title><style>" +
    "body{font-family:sans-serif;margin:0;padding:24px;line-height:1.6;" +
    "color:#111;max-width:560px}" +
    "h2{margin:0 0 4px}.ok{color:#15803d;font-weight:700;margin:0 0 16px}" +
    "table{border-collapse:collapse;width:100%;margin-bottom:20px}" +
    "th,td{border:1px solid #d1d5db;padding:8px 10px;text-align:left}" +
    "th{background:#f3f4f6;width:36%}.box{border:1px solid #d1d5db;" +
    "padding:12px;border-radius:6px}#r{margin-top:10px;font-weight:700}" +
    ".good{color:#15803d}.bad{color:#b91c1c}.hint{color:#6b7280;" +
    "font-size:13px}</style></head><body>" +
    "<h2>계약서 진위 확인</h2>" +
    "<p class=\"ok\">서버에 기록된 계약서입니다.</p>" +
    `<table>${rows}</table>` +
    "<div class=\"box\"><b>받은 PDF 파일 확인</b>" +
    "<p class=\"hint\">받은 계약서 PDF를 고르면 파일이 원본과 같은지 " +
    "이 기기에서 계산해 확인합니다. 파일은 서버로 전송되지 않습니다.</p>" +
    "<input id=\"f\" type=\"file\" accept=\"application/pdf\">" +
    "<div id=\"r\"></div></div>" +
    "<script>" +
    "document.getElementById('f').addEventListener('change',async function(e){" +
    "var r=document.getElementById('r');var file=e.target.files[0];" +
    "if(!file){r.textContent='';return;}" +
    "r.className='';r.textContent='확인 중…';" +
    "try{var buf=await file.arrayBuffer();" +
    "var d=await crypto.subtle.digest('SHA-256',buf);" +
    "var h=Array.from(new Uint8Array(d)).map(function(b){" +
    "return b.toString(16).padStart(2,'0');}).join('');" +
    `var res=await fetch('${endpoint}&format=json&h='+h);` +
    "var j=await res.json();" +
    "if(j.match){r.className='good';" +
    "r.textContent='원본과 같은 파일입니다. 내용이 바뀌지 않았습니다.';}" +
    "else{r.className='bad';" +
    "r.textContent='원본과 다른 파일입니다. 내용이 바뀌었을 수 있습니다.';}" +
    "}catch(err){r.className='bad';" +
    "r.textContent='확인하지 못했어요. 잠시 후 다시 시도해 주세요.';}});" +
    "</script></body></html>";
}

export function createVerifyPersonalContractHandler(db: Db) {
  return async (req: Req, res: Res) => {
    res.set({
      "Cache-Control": "private, no-store",
      "X-Content-Type-Options": "nosniff",
      "Referrer-Policy": "no-referrer",
      "X-Robots-Tag": "noindex, nofollow",
    });
    if (req.method !== "GET" && req.method !== "HEAD") {
      res.set("Allow", "GET, HEAD");
      res.status(405).send("");
      return;
    }
    const contractId = typeof req.query.c === "string" ? req.query.c : "";
    const code = typeof req.query.k === "string" ? req.query.k : "";
    const wantsJson = req.query.format === "json";
    const fileHash = typeof req.query.h === "string" ? req.query.h : "";
    const reject = () => {
      if (wantsJson) {
        res.status(404).json({ok: false});
        return;
      }
      sendPage(
        res,
        404,
        "확인할 수 없는 문서예요",
        "QR 코드나 문서확인번호가 올바르지 않거나, 서버에 기록되지 않은 문서입니다.",
      );
    };
    // 형식이 맞지 않으면 DB를 읽지 않고 같은 404로 답한다(계약 ID·번호 추측 방지).
    if (!CONTRACT_ID_PATTERN.test(contractId) ||
        !VERIFY_CODE_PATTERN.test(code)) {
      reject();
      return;
    }
    try {
      const snap = await db.collection(CONTRACTS).doc(contractId).get();
      const contract = snap.data();
      const contentHash = String(contract?.contentHash ?? "");
      if (!contract ||
          (contract.status !== "completed" &&
           contract.status !== "terminated" &&
           contract.status !== "superseded" &&
           contract.status !== "voided") ||
          contentHash.length < 16 ||
          contractVerificationCode(contentHash) !== code.toUpperCase()) {
        reject();
        return;
      }
      const delivery = (contract.delivery ?? {}) as Data;
      if (wantsJson) {
        const stored = typeof delivery.pdfHash === "string" ?
          delivery.pdfHash :
          "";
        res.status(200).json({
          ok: true,
          match: FILE_HASH_PATTERN.test(fileHash) &&
            stored !== "" &&
            fileHash === stored,
        });
        return;
      }
      const completedAt = contract.completedAt instanceof Timestamp ?
        formatKst(contract.completedAt.toDate()) :
        "";
      const upper = code.toUpperCase();
      res.status(200);
      res.set({
        "Content-Type": "text/html; charset=utf-8",
        "Content-Security-Policy":
          "default-src 'none'; style-src 'unsafe-inline'; " +
          "script-src 'unsafe-inline'; connect-src 'self'",
      });
      res.send(verifyPage({
        contractId,
        code: upper,
        contractNo: String(contract.contractNo ?? ""),
        completedAt,
        statusLabel: contract.status === "superseded" ?
          "새 버전이 발행되어 이 문서는 이전 버전입니다" :
          contract.status === "voided" ?
            "파기된 계약서입니다(효력 없음)" :
            contract.status === "terminated" ?
              "체결 후 해지된 계약서입니다(서명·내용은 체결 당시 그대로입니다)" :
              "유효한 계약서",
        codeText: upper.match(/.{4}/gu)?.join("-") ?? upper,
      }));
    } catch (error) {
      functions.logger.error("[MTF_PERSONAL_CONTRACT] verify failed", {
        errorName: error instanceof Error ? error.name : "UnknownError",
      });
      sendPage(
        res,
        500,
        "확인하지 못했어요",
        "잠시 후 다시 시도해 주세요.",
      );
    }
  };
}

// 기본 Storage 버킷에서 PDF를 읽는 저장소.
export function createBucketPdfStore(
  bucketGetter: () => {
    file(path: string): {
      exists(): Promise<[boolean]>;
      getMetadata(): Promise<[{size?: string | number}, ...unknown[]]>;
      download(): Promise<[Buffer]>;
    };
  },
): PdfStore {
  return {
    async read(path: string): Promise<Buffer | null> {
      const file = bucketGetter().file(path);
      const [exists] = await file.exists();
      if (!exists) return null;
      const [metadata] = await file.getMetadata();
      if (Number(metadata.size ?? 0) > MAX_PDF_BYTES) {
        throw new PdfTooLargeError("pdf_too_large");
      }
      const [bytes] = await file.download();
      return bytes;
    },
  };
}
