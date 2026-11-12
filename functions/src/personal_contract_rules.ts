import {createHash} from "crypto";

// 레슨계약서 v2 규칙. 서버 callable과 테스트가 같은 규칙을 쓰도록 순수 함수로 둔다.
// 근거 문서: docs/product/lesson-contract-spec.md

export const CONTRACT_TEMPLATE_VERSION = "lesson-contract-2026.10-v1";

export const CONTRACT_STATUSES = [
  "draft",
  "disclosed",
  "member_signed",
  "completed",
  "cancelled",
  "superseded",
  "voided",
  "terminated",
] as const;
export type ContractStatus = typeof CONTRACT_STATUSES[number];

export const OPEN_STATUSES: ContractStatus[] = [
  "draft",
  "disclosed",
  "member_signed",
];

export type SignStep = "disclosure" | "member" | "trainer";

export const MAX_PENALTY_PERCENT = 10;
export const DEFAULT_PENALTY_PERCENT = 10;
export const DEFAULT_CANCEL_DEADLINE_HOURS = 24;
// 환급 처리 기한은 사용자가 최대 약 6개월(130영업일)까지 입력할 수 있다(2026-10-17 결정).
// 3영업일을 넘기면 앱이 입력 시점에 안내하고, 법정 기한은 전문가 확인(명세서 §18-5) 대상이다.
export const MAX_REFUND_BUSINESS_DAYS = 130;
export const MAX_PERIOD_DAYS = 1095;

export type ContractIssue = {code: string; field: string};

export class ContractValidationError extends Error {
  constructor(readonly issue: ContractIssue) {
    super(issue.code);
  }
}

type Data = Record<string, unknown>;

function fail(code: string, field = ""): never {
  throw new ContractValidationError({code, field});
}

function isRecord(value: unknown): value is Data {
  return value != null && typeof value === "object" && !Array.isArray(value);
}

function record(value: unknown, field: string): Data {
  if (!isRecord(value)) fail("invalid_object", field);
  return value;
}

function allowOnly(data: Data, keys: string[], field: string): void {
  if (Object.keys(data).some((key) => !keys.includes(key))) {
    fail("unknown_fields", field);
  }
}

function text(
  data: Data,
  key: string,
  field: string,
  min: number,
  max: number,
): string {
  const value = data[key];
  if (typeof value !== "string") fail(`${key}_required`, field);
  const normalized = value.normalize("NFC").trim().replace(/[ \t]+/gu, " ");
  if (normalized.length < min || normalized.length > max) {
    fail(`${key}_invalid`, field);
  }
  return normalized;
}

function optionalText(
  data: Data,
  key: string,
  field: string,
  max: number,
): string {
  const value = data[key];
  if (value == null || value === "") return "";
  if (typeof value !== "string") fail(`${key}_invalid`, field);
  const normalized = value.normalize("NFC").trim();
  if (normalized.length > max) fail(`${key}_invalid`, field);
  return normalized;
}

function integer(
  data: Data,
  key: string,
  field: string,
  min: number,
  max: number,
): number {
  const value = data[key];
  if (typeof value !== "number" || !Number.isInteger(value) ||
      value < min || value > max) {
    fail(`${key}_invalid`, field);
  }
  return value;
}

function oneOf<T extends string>(
  data: Data,
  key: string,
  field: string,
  values: readonly T[],
): T {
  const value = data[key];
  if (typeof value !== "string" || !values.includes(value as T)) {
    fail(`${key}_invalid`, field);
  }
  return value as T;
}

// ---- 금지·경고 문구 가드 (명세서 §12) ----
// 공백·구두점을 제거한 문자열에서 찾는다. 자유 입력 칸에만 적용한다.
const FORBIDDEN_PHRASES: Array<{code: string; pattern: RegExp}> = [
  {code: "refund_denied", pattern: /환불(은|이)?(불가|안됩|안돼|안됨|금지|없)/u},
  {code: "refund_denied", pattern: /환불(을)?(하지않|해드리지않|불가)/u},
  {code: "refund_short_window", pattern: /환불(신청)?(은)?\d+일(이내|내|까지)/u},
  {code: "simple_change_of_mind", pattern: /단순변심/u},
  {code: "card_fee_deduction", pattern: /카드수수료/u},
  {code: "fee_deduction", pattern: /수수료(를)?공제/u},
  {code: "jurisdiction_fixed", pattern: /(재판관할|관할법원|관할로한다)/u},
  {code: "blanket_disclaimer", pattern: /(모든|어떠한|일체의?)(사고|상해|손실|책임)/u},
  {code: "blanket_disclaimer", pattern: /책임(을|은)?(지지않|없)/u},
  {code: "oral_agreement_void", pattern: /(구두|서면)약정(은|이)?(효력|무효)/u},
];

export function findForbiddenPhrase(input: string): string | null {
  const squashed = input.normalize("NFC").replace(/[\s.,·:;!?'"()[\]-]+/gu, "");
  for (const rule of FORBIDDEN_PHRASES) {
    if (rule.pattern.test(squashed)) return rule.code;
  }
  return null;
}

function guardedText(
  data: Data,
  key: string,
  field: string,
  min: number,
  max: number,
): string {
  const value = text(data, key, field, min, max);
  const hit = findForbiddenPhrase(value);
  if (hit != null) fail(`forbidden_phrase:${hit}`, field);
  return value;
}

function guardedOptionalText(
  data: Data,
  key: string,
  field: string,
  max: number,
): string {
  const value = optionalText(data, key, field, max);
  const hit = value === "" ? null : findForbiddenPhrase(value);
  if (hit != null) fail(`forbidden_phrase:${hit}`, field);
  return value;
}

// ---- 날짜 ----
const DATE_PATTERN = /^\d{4}-\d{2}-\d{2}$/u;

function dateText(data: Data, key: string, field: string): string {
  const value = data[key];
  if (typeof value !== "string" || !DATE_PATTERN.test(value)) {
    fail(`${key}_invalid`, field);
  }
  const parsed = new Date(`${value}T00:00:00Z`);
  if (Number.isNaN(parsed.getTime()) ||
      parsed.toISOString().slice(0, 10) !== value) {
    fail(`${key}_invalid`, field);
  }
  return value;
}

function dayNumber(value: string): number {
  return Date.parse(`${value}T00:00:00Z`) / 86400000;
}

const PHONE_PATTERN = /^[0-9+\-\s()]{8,20}$/u;

function phone(data: Data, key: string, field: string): string {
  const value = text(data, key, field, 8, 20);
  if (!PHONE_PATTERN.test(value)) fail(`${key}_invalid`, field);
  return value;
}

// ---- 정규화된 계약 내용 ----
export type PartyKind = "center" | "individual";
export type Party = {
  kind: PartyKind;
  name: string;
  trainerName: string;
  phone: string;
  place: string;
  businessNo: string;
  logoPath: string;
};

export type MemberInfo = {
  name: string;
  phone: string;
  birthDate: string;
  email: string;
};

export type Product = {
  name: string;
  serviceContent: string;
  sessionCount: number;
  sessionMinutes: number;
  paidAmount: number;
  vatIncluded: boolean;
  listPrice: number | null;
  paymentMethod: string;
  paymentDate: string;
  periodStart: string;
  // 종료일이 없는 계약이면 빈 문자열이고 periodUnlimited가 true다.
  periodEnd: string;
  // 종료일이 없는 계약일 때만 저장해 기존 계약의 내용 해시는 그대로 둔다.
  periodUnlimited?: true;
  // 안내용 비고(예: 분할결제 일정). 입력했을 때만 저장해 기존 계약의 내용 해시는 그대로 둔다.
  remarks?: string;
};

export type Terms = {
  cancelDeadline: {mode: "same_day" | "hours_before"; hours: number};
  lateNoShowMinutes: number | null;
  penaltyPercent: number;
  refundBasis: "contract_unit" | "list_price";
  refundBusinessDays: number;
  transfer: {
    policy: "allowed" | "denied" | "conditional";
    feeType: "none" | "amount" | "percent";
    feeValue: number;
  };
  expiryExtensionClause: boolean;
  unavoidableRefundClause: boolean;
  extraTerms: string;
  // 고정 값: 입력으로 받지 않고 서버가 채운다.
  lateCancelDeduction: 1;
  noShowDeduction: 1;
  trainerCancelDeduction: 0;
  trainerCancelMakeup: true;
  // 유효기간 종료일이 있는 계약은 기간이 지나면 남은 횟수가 소멸한다(종료일 없는 계약은 false).
  expiryForfeit: boolean;
};

export type ContractContent = {
  party: Party;
  member: MemberInfo;
  product: Product;
  terms: Terms;
};

export type DraftPayload = {
  memberId: string;
  content: ContractContent;
};

const BUSINESS_NO_PATTERN = /^\d{3}-?\d{2}-?\d{5}$/u;

export function normalizeParty(raw: unknown, uid: string): Party {
  const data = record(raw, "party");
  allowOnly(data, [
    "kind", "name", "trainerName", "phone", "place", "businessNo", "logoPath",
  ], "party");
  const kind = oneOf(data, "kind", "party.kind", ["center", "individual"]);
  const businessNo = optionalText(data, "businessNo", "party.businessNo", 12);
  if (businessNo !== "" && !BUSINESS_NO_PATTERN.test(businessNo)) {
    fail("businessNo_invalid", "party.businessNo");
  }
  const logoPath = optionalText(data, "logoPath", "party.logoPath", 200);
  if (logoPath !== "" &&
      (!logoPath.startsWith(`contract_logos/${uid}/`) ||
       logoPath.includes(".."))) {
    fail("logoPath_invalid", "party.logoPath");
  }
  return {
    kind,
    name: text(data, "name", "party.name", 2, 40),
    trainerName: text(data, "trainerName", "party.trainerName", 2, 20),
    phone: phone(data, "phone", "party.phone"),
    place: text(data, "place", "party.place", 2, 100),
    businessNo,
    logoPath,
  };
}

export function normalizeMemberInfo(raw: unknown): MemberInfo {
  const data = record(raw, "member");
  allowOnly(data, ["name", "phone", "birthDate", "email"], "member");
  const birthDate = optionalText(data, "birthDate", "member.birthDate", 10);
  if (birthDate !== "") dateText({birthDate}, "birthDate", "member.birthDate");
  const email = optionalText(data, "email", "member.email", 100);
  if (email !== "" && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/u.test(email)) {
    fail("email_invalid", "member.email");
  }
  return {
    name: text(data, "name", "member.name", 2, 20),
    phone: phone(data, "phone", "member.phone"),
    birthDate,
    email,
  };
}

export function normalizeProduct(raw: unknown): Product {
  const data = record(raw, "product");
  allowOnly(data, [
    "name", "serviceContent", "sessionCount", "sessionMinutes", "paidAmount",
    "vatIncluded", "listPrice", "paymentMethod", "paymentDate", "periodStart",
    "periodEnd", "periodUnlimited", "remarks",
  ], "product");
  if (data.periodUnlimited != null && typeof data.periodUnlimited !== "boolean") {
    fail("periodUnlimited_invalid", "product.periodUnlimited");
  }
  const periodUnlimited = data.periodUnlimited === true;
  const remarks = guardedOptionalText(data, "remarks", "product.remarks", 100);
  if (data.vatIncluded != null && typeof data.vatIncluded !== "boolean") {
    fail("vatIncluded_invalid", "product.vatIncluded");
  }
  const paidAmount = integer(
    data, "paidAmount", "product.paidAmount", 1, 100000000,
  );
  let listPrice: number | null = null;
  if (data.listPrice != null) {
    listPrice = integer(
      data, "listPrice", "product.listPrice", paidAmount + 1, 1000000000,
    );
  }
  const paymentMethod = data.paymentMethod == null || data.paymentMethod === "" ?
    "" :
    oneOf(data, "paymentMethod", "product.paymentMethod",
      ["cash", "card", "transfer", "other"]);
  const paymentDate = data.paymentDate == null || data.paymentDate === "" ?
    "" :
    dateText(data, "paymentDate", "product.paymentDate");
  const periodStart = dateText(data, "periodStart", "product.periodStart");
  let periodEnd = "";
  if (periodUnlimited) {
    if (data.periodEnd != null && data.periodEnd !== "") {
      fail("period_invalid", "product.periodEnd");
    }
  } else {
    periodEnd = dateText(data, "periodEnd", "product.periodEnd");
    const span = dayNumber(periodEnd) - dayNumber(periodStart);
    if (span < 0 || span > MAX_PERIOD_DAYS) {
      fail("period_invalid", "product.periodEnd");
    }
  }
  return {
    name: guardedText(data, "name", "product.name", 1, 40),
    serviceContent: guardedText(
      data, "serviceContent", "product.serviceContent", 2, 200,
    ),
    sessionCount: integer(data, "sessionCount", "product.sessionCount", 1, 200),
    sessionMinutes: integer(
      data, "sessionMinutes", "product.sessionMinutes", 10, 180,
    ),
    paidAmount,
    vatIncluded: data.vatIncluded === true,
    listPrice,
    paymentMethod,
    paymentDate,
    periodStart,
    periodEnd,
    ...(periodUnlimited ? {periodUnlimited: true as const} : {}),
    ...(remarks !== "" ? {remarks} : {}),
  };
}

export function normalizeTerms(raw: unknown, product: Product): Terms {
  const data = record(raw, "terms");
  allowOnly(data, [
    "cancelDeadline", "lateNoShowMinutes", "penaltyPercent", "refundBasis",
    "refundBusinessDays", "transfer", "expiryExtensionClause",
    "unavoidableRefundClause", "extraTerms",
  ], "terms");
  const deadline = record(data.cancelDeadline, "terms.cancelDeadline");
  allowOnly(deadline, ["mode", "hours"], "terms.cancelDeadline");
  const mode = oneOf(deadline, "mode", "terms.cancelDeadline.mode",
    ["same_day", "hours_before"] as const);
  const hours = mode === "same_day" ? 0 :
    integer(deadline, "hours", "terms.cancelDeadline.hours", 1, 72);

  let lateNoShowMinutes: number | null = null;
  if (data.lateNoShowMinutes != null) {
    lateNoShowMinutes = integer(
      data, "lateNoShowMinutes", "terms.lateNoShowMinutes", 10, 60,
    );
  }
  const penaltyPercent = integer(
    data, "penaltyPercent", "terms.penaltyPercent", 0, MAX_PENALTY_PERCENT,
  );
  const refundBasis = oneOf(data, "refundBasis", "terms.refundBasis",
    ["contract_unit", "list_price"] as const);
  if (refundBasis === "list_price" && product.listPrice == null) {
    fail("listPrice_required_for_basis", "terms.refundBasis");
  }
  const refundBusinessDays = integer(
    data, "refundBusinessDays", "terms.refundBusinessDays",
    1, MAX_REFUND_BUSINESS_DAYS,
  );

  const transfer = record(data.transfer, "terms.transfer");
  allowOnly(transfer, ["policy", "feeType", "feeValue"], "terms.transfer");
  const policy = oneOf(transfer, "policy", "terms.transfer.policy",
    ["allowed", "denied", "conditional"] as const);
  const feeType = oneOf(transfer, "feeType", "terms.transfer.feeType",
    ["none", "amount", "percent"] as const);
  let feeValue = 0;
  if (feeType === "amount") {
    feeValue = integer(
      transfer, "feeValue", "terms.transfer.feeValue", 1,
      Math.floor(product.paidAmount / 10),
    );
  } else if (feeType === "percent") {
    feeValue = integer(
      transfer, "feeValue", "terms.transfer.feeValue", 1, MAX_PENALTY_PERCENT,
    );
  }
  if (policy === "denied" && feeType !== "none") {
    fail("transfer_fee_without_policy", "terms.transfer.feeType");
  }

  const boolFlag = (key: string): boolean => {
    const value = data[key];
    if (typeof value !== "boolean") fail(`${key}_invalid`, `terms.${key}`);
    return value;
  };

  return {
    cancelDeadline: {mode, hours},
    lateNoShowMinutes,
    penaltyPercent,
    refundBasis,
    refundBusinessDays,
    transfer: {policy, feeType, feeValue},
    expiryExtensionClause: boolFlag("expiryExtensionClause"),
    unavoidableRefundClause: boolFlag("unavoidableRefundClause"),
    extraTerms: guardedOptionalText(data, "extraTerms", "terms.extraTerms", 500),
    lateCancelDeduction: 1,
    noShowDeduction: 1,
    trainerCancelDeduction: 0,
    trainerCancelMakeup: true,
    expiryForfeit: !product.periodUnlimited,
  };
}

// ---- 설정(내 기본 조건) ----
// 새 계약을 시작할 때 채워지는 기본값이다. 정상가 기준·추가 특약·금액 정액 수수료는
// 계약마다 정하는 값이라 기본 조건에는 넣지 않는다.
export type ContractDefaults = Pick<Terms,
  "cancelDeadline" | "lateNoShowMinutes" | "penaltyPercent" |
  "refundBusinessDays" | "transfer" | "expiryExtensionClause" |
  "unavoidableRefundClause">;

const DEFAULT_KEYS = [
  "cancelDeadline", "lateNoShowMinutes", "penaltyPercent",
  "refundBusinessDays", "transfer", "expiryExtensionClause",
  "unavoidableRefundClause",
];

const SETTINGS_PRODUCT: Product = {
  name: "", serviceContent: "", sessionCount: 1, sessionMinutes: 50,
  paidAmount: 100000000, vatIncluded: false, listPrice: null, paymentMethod: "",
  paymentDate: "",
  periodStart: "2026-01-01", periodEnd: "2026-01-02",
};

export function normalizeContractDefaults(raw: unknown): ContractDefaults {
  const data = record(raw, "contractDefaults");
  allowOnly(data, DEFAULT_KEYS, "contractDefaults");
  const transfer = record(data.transfer, "contractDefaults.transfer");
  if (transfer.feeType === "amount") {
    fail("transfer_amount_not_allowed_in_defaults", "contractDefaults.transfer");
  }
  const terms = normalizeTerms(
    {...data, refundBasis: "contract_unit", extraTerms: ""},
    SETTINGS_PRODUCT,
  );
  return {
    cancelDeadline: terms.cancelDeadline,
    lateNoShowMinutes: terms.lateNoShowMinutes,
    penaltyPercent: terms.penaltyPercent,
    refundBusinessDays: terms.refundBusinessDays,
    transfer: terms.transfer,
    expiryExtensionClause: terms.expiryExtensionClause,
    unavoidableRefundClause: terms.unavoidableRefundClause,
  };
}

// ---- 센터 로고 ----
// 마이페이지에서 올린 로고 경로. 빈 문자열이면 로고를 지운다.
const LOGO_PATH_PATTERN = /^contract_logos\/[^/]+\/logo_[0-9]+\.png$/u;

export function normalizeCenterLogoPath(raw: unknown, uid: string): string {
  if (typeof raw !== "string") fail("centerLogoPath_invalid", "centerLogoPath");
  const value = raw.trim();
  if (value === "") return "";
  if (value.length > 200 || !LOGO_PATH_PATTERN.test(value) ||
      !value.startsWith(`contract_logos/${uid}/`)) {
    fail("logoPath_invalid", "centerLogoPath");
  }
  return value;
}

// ---- 내 수업 상품 ----
// 계약 입력 화면에서 불러오는 상품 목록. 기간·결제 정보는 계약마다 정한다.
export const MAX_PRODUCT_PRESETS = 20;

export type ProductPreset = {
  name: string;
  serviceContent: string;
  sessionCount: number;
  sessionMinutes: number;
  paidAmount: number;
  listPrice: number | null;
};

export function normalizeProductPresets(raw: unknown): ProductPreset[] {
  if (!Array.isArray(raw)) fail("invalid_object", "contractProducts");
  if (raw.length > MAX_PRODUCT_PRESETS) {
    fail("products_too_many", "contractProducts");
  }
  const seen = new Set<string>();
  return raw.map((item, index) => {
    const field = `contractProducts[${index}]`;
    const data = record(item, field);
    allowOnly(data, [
      "name", "serviceContent", "sessionCount", "sessionMinutes",
      "paidAmount", "listPrice",
    ], field);
    const name = guardedText(data, "name", `${field}.name`, 1, 40);
    const key = name.toLocaleLowerCase("ko-KR");
    if (seen.has(key)) fail("product_name_duplicate", `${field}.name`);
    seen.add(key);
    const paidAmount = integer(
      data, "paidAmount", `${field}.paidAmount`, 1, 100000000,
    );
    let listPrice: number | null = null;
    if (data.listPrice != null) {
      listPrice = integer(
        data, "listPrice", `${field}.listPrice`, paidAmount + 1, 1000000000,
      );
    }
    return {
      name,
      serviceContent: guardedText(
        data, "serviceContent", `${field}.serviceContent`, 2, 200,
      ),
      sessionCount: integer(
        data, "sessionCount", `${field}.sessionCount`, 1, 200,
      ),
      sessionMinutes: integer(
        data, "sessionMinutes", `${field}.sessionMinutes`, 10, 180,
      ),
      paidAmount,
      listPrice,
    };
  });
}

export function normalizeContent(raw: unknown, uid: string): ContractContent {
  const data = record(raw, "content");
  allowOnly(data, ["party", "member", "product", "terms"], "content");
  const product = normalizeProduct(data.product);
  return {
    party: normalizeParty(data.party, uid),
    member: normalizeMemberInfo(data.member),
    product,
    terms: normalizeTerms(data.terms, product),
  };
}

// ---- 해시 ----
export function canonicalJson(value: unknown): string {
  if (value === null || typeof value !== "object") {
    return JSON.stringify(value ?? null);
  }
  if (Array.isArray(value)) {
    return `[${value.map((item) => canonicalJson(item)).join(",")}]`;
  }
  const entries = Object.entries(value as Data)
    .filter(([, item]) => item !== undefined)
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0));
  return `{${entries
    .map(([key, item]) => `${JSON.stringify(key)}:${canonicalJson(item)}`)
    .join(",")}}`;
}

export function contentHash(content: ContractContent): string {
  return createHash("sha256")
    .update(canonicalJson({
      templateVersion: CONTRACT_TEMPLATE_VERSION,
      ...content,
    }), "utf8")
    .digest("hex");
}

// ---- 고지 확인 항목 ----
export function requiredDisclosureItems(content: ContractContent): string[] {
  const items = ["amount", "refund", "validity", "cancel_noshow", "health_risk"];
  if (content.terms.refundBasis === "list_price") {
    items.push("list_price_basis");
  }
  return items;
}

export const MEMBER_AGREEMENT_ITEMS = ["terms", "privacy"];

export function validateCheckedItems(
  raw: unknown,
  required: string[],
): string[] {
  if (!Array.isArray(raw) || raw.some((item) => typeof item !== "string")) {
    fail("checkedItems_invalid", "checkedItems");
  }
  const checked = Array.from(new Set(raw as string[])).sort();
  const expected = [...required].sort();
  if (checked.length !== expected.length ||
      checked.some((item, index) => item !== expected[index])) {
    fail("checkedItems_mismatch", "checkedItems");
  }
  return checked;
}

// ---- 서명(획) ----
export const MAX_STROKES = 40;
export const MAX_SIGNATURE_POINTS = 4000;
export const MIN_SIGNATURE_POINTS = 8;

// 입력은 [[ [x,y], ... ], ...] 이지만 Firestore는 배열 안의 배열을 저장하지 못해
// 저장할 때는 획마다 [x1,y1,x2,y2,...] 평면 배열을 가진 맵으로 바꾼다.
export type StoredStroke = {points: number[]};

export function validateStrokes(raw: unknown): StoredStroke[] {
  if (!Array.isArray(raw) || raw.length < 1 || raw.length > MAX_STROKES) {
    fail("strokes_invalid", "strokes");
  }
  let total = 0;
  const strokes = raw.map((stroke) => {
    if (!Array.isArray(stroke) || stroke.length < 1) {
      fail("strokes_invalid", "strokes");
    }
    const points: number[] = [];
    stroke.forEach((point) => {
      if (!Array.isArray(point) || point.length !== 2 ||
          point.some((n) => typeof n !== "number" || !Number.isFinite(n) ||
            n < 0 || n > 1000)) {
        fail("strokes_invalid", "strokes");
      }
      total += 1;
      points.push(
        Math.round(point[0] * 100) / 100,
        Math.round(point[1] * 100) / 100,
      );
    });
    return {points};
  });
  if (total < MIN_SIGNATURE_POINTS || total > MAX_SIGNATURE_POINTS) {
    fail("strokes_invalid", "strokes");
  }
  return strokes;
}

// ---- 상태 전이 ----
const STEP_TRANSITIONS: Record<SignStep, {
  from: ContractStatus;
  to: ContractStatus;
}> = {
  disclosure: {from: "draft", to: "disclosed"},
  member: {from: "disclosed", to: "member_signed"},
  trainer: {from: "member_signed", to: "completed"},
};

export function signTransition(step: SignStep): {
  from: ContractStatus;
  to: ContractStatus;
} {
  return STEP_TRANSITIONS[step];
}

export function isSignStep(value: unknown): value is SignStep {
  return value === "disclosure" || value === "member" || value === "trainer";
}

export function isOpenStatus(status: unknown): boolean {
  return OPEN_STATUSES.includes(status as ContractStatus);
}

// ---- 계약번호 ----
const KST_OFFSET_MS = 9 * 60 * 60 * 1000;

export function kstYearMonth(now: Date): {yyyyMM: string; yyMM: string} {
  const kst = new Date(now.getTime() + KST_OFFSET_MS);
  const year = String(kst.getUTCFullYear());
  const month = String(kst.getUTCMonth() + 1).padStart(2, "0");
  return {yyyyMM: `${year}${month}`, yyMM: `${year.slice(2)}${month}`};
}

export function formatContractNo(yyMM: string, sequence: number): string {
  return `PT-${yyMM}-${String(sequence).padStart(4, "0")}`;
}

export function displayContractNo(contractNo: string, version: number): string {
  return version > 1 ? `${contractNo}-v${version}` : contractNo;
}

// ---- 환불 계산 (명세서 §6) ----
export type RefundKind =
  | "before_first_lesson"
  | "member_reason"
  | "provider_fault"
  | "unavoidable";

export type RefundResult = {
  unitPrice: number;
  consumed: number;
  penalty: number;
  refund: number;
};

export function unitPrice(amount: number, sessionCount: number): number {
  return Math.round(amount / sessionCount);
}

export function computeRefund(args: {
  kind: RefundKind;
  paidAmount: number;
  sessionCount: number;
  usedSessions: number;
  listPrice: number | null;
  basis: "contract_unit" | "list_price";
  penaltyPercent: number;
}): RefundResult {
  const {paidAmount, sessionCount, usedSessions} = args;
  if (sessionCount < 1 || usedSessions < 0 || usedSessions > sessionCount) {
    fail("refund_input_invalid");
  }
  if (args.penaltyPercent < 0 || args.penaltyPercent > MAX_PENALTY_PERCENT) {
    fail("refund_input_invalid");
  }
  const contractUnit = unitPrice(paidAmount, sessionCount);
  const basisAmount = args.basis === "list_price" && args.listPrice != null ?
    args.listPrice : paidAmount;
  const consumedUnit = unitPrice(basisAmount, sessionCount);
  const penalty = Math.floor(paidAmount * args.penaltyPercent / 100);

  if (args.kind === "provider_fault") {
    const remaining = sessionCount - usedSessions;
    const refund = Math.min(paidAmount, remaining * contractUnit);
    return {unitPrice: contractUnit, consumed: paidAmount - refund,
      penalty: 0, refund};
  }
  if (args.kind === "before_first_lesson") {
    return {unitPrice: contractUnit, consumed: 0, penalty,
      refund: Math.max(0, paidAmount - penalty)};
  }
  const consumed = usedSessions * consumedUnit;
  const penaltyApplied = args.kind === "unavoidable" ? 0 : penalty;
  // 소진분 + 위약금이 결제금액을 넘으면 환불 0, 추가 청구 없음.
  const refund = Math.max(0, paidAmount - consumed - penaltyApplied);
  return {unitPrice: consumedUnit, consumed, penalty: penaltyApplied, refund};
}
