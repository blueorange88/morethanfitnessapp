import * as functions from "firebase-functions/v1";

const TIER_NAMES = [
  "Beginner",
  "Amateur",
  "Semi-Pro",
  "Pro",
  "Master",
  "Grand Prix",
] as const;

export type EarnedTier = typeof TIER_NAMES[number];

function collapsed(value: unknown): string {
  return typeof value === "string" ? value.trim().replace(/\s+/g, " ") : "";
}

export function isValidTrainerRealName(value: unknown): boolean {
  const text = collapsed(value);
  if (text.length < 2 || text.length > 20) return false;
  if (!/^[가-힣A-Za-z ]+$/.test(text)) return false;
  return !/^[ㄱ-ㅎㅏ-ㅣ]+$/.test(text);
}

export function isValidTrainerJobTitle(value: unknown): boolean {
  const text = collapsed(value);
  if (text.length < 2 || text.length > 30) return false;
  return /[가-힣A-Za-z0-9]/.test(text) &&
    /^[가-힣A-Za-z0-9 &/·._-]+$/.test(text);
}

export function isTrainerJobTitleRequired(affiliationType: unknown): boolean {
  return ["center", "personal_shop"].includes(collapsed(affiliationType));
}

export function isValidTrainerJobTitleForAffiliation(
  value: unknown,
  affiliationType: unknown,
): boolean {
  const text = collapsed(value);
  return text.length === 0 ? !isTrainerJobTitleRequired(affiliationType) :
    isValidTrainerJobTitle(text);
}

export function isValidTrainerEnglishName(value: unknown): boolean {
  const text = collapsed(value);
  if (text.length === 0) return true;
  return text.length >= 2 && text.length <= 40 && /[A-Za-z]/.test(text) &&
    /^[A-Za-z '-]+$/.test(text);
}

export function isValidPrimaryActivity(value: unknown): boolean {
  const text = collapsed(value);
  return text.length >= 2 && text.length <= 30 &&
    /[가-힣A-Za-z0-9]/.test(text) &&
    /^[가-힣A-Za-z0-9 &/·._-]+$/.test(text);
}

export function isValidAffiliationType(value: unknown): boolean {
  return ["freelancer", "center", "personal_shop"].includes(collapsed(value));
}

export function isValidActivityRegion(value: unknown): boolean {
  const text = collapsed(value);
  return text.length >= 4 && text.length <= 40 &&
    /^[가-힣 ]+$/.test(text) && text.includes(" ");
}

const ACTIVITY_REGIONS = new Set([
  "서울특별시 강남구", "서울특별시 강동구", "서울특별시 강서구", "서울특별시 관악구",
  "서울특별시 광진구", "서울특별시 구로구", "서울특별시 노원구", "서울특별시 마포구",
  "서울특별시 서초구", "서울특별시 성동구", "서울특별시 송파구", "서울특별시 영등포구",
  "서울특별시 용산구", "서울특별시 종로구", "서울특별시 중구",
  "부산광역시 강서구", "부산광역시 금정구", "부산광역시 남구", "부산광역시 동래구",
  "부산광역시 부산진구", "부산광역시 북구", "부산광역시 수영구", "부산광역시 연제구",
  "부산광역시 해운대구", "대구광역시 달서구", "대구광역시 달성군", "대구광역시 동구",
  "대구광역시 북구", "대구광역시 수성구", "대구광역시 중구", "인천광역시 계양구",
  "인천광역시 남동구", "인천광역시 미추홀구", "인천광역시 부평구", "인천광역시 서구",
  "인천광역시 연수구", "광주광역시 광산구", "광주광역시 남구", "광주광역시 동구",
  "광주광역시 북구", "광주광역시 서구", "대전광역시 대덕구", "대전광역시 동구",
  "대전광역시 서구", "대전광역시 유성구", "대전광역시 중구", "울산광역시 남구",
  "울산광역시 동구", "울산광역시 북구", "울산광역시 울주군", "울산광역시 중구",
  "세종특별자치시 세종시", "경기도 고양시", "경기도 광명시", "경기도 김포시",
  "경기도 남양주시", "경기도 부천시", "경기도 성남시", "경기도 수원시", "경기도 시흥시",
  "경기도 안산시", "경기도 안양시", "경기도 용인시", "경기도 의정부시", "경기도 파주시",
  "경기도 평택시", "경기도 하남시", "경기도 화성시", "강원특별자치도 강릉시",
  "강원특별자치도 속초시", "강원특별자치도 원주시", "강원특별자치도 춘천시",
  "충청북도 제천시", "충청북도 청주시", "충청북도 충주시", "충청남도 공주시",
  "충청남도 아산시", "충청남도 천안시", "전북특별자치도 군산시",
  "전북특별자치도 익산시", "전북특별자치도 전주시", "전라남도 광양시",
  "전라남도 나주시", "전라남도 목포시", "전라남도 순천시", "전라남도 여수시",
  "경상북도 경산시", "경상북도 경주시", "경상북도 구미시", "경상북도 안동시",
  "경상북도 포항시", "경상남도 거제시", "경상남도 김해시", "경상남도 양산시",
  "경상남도 진주시", "경상남도 창원시", "제주특별자치도 서귀포시", "제주특별자치도 제주시",
]);

export function isKnownActivityRegion(value: unknown): boolean {
  return ACTIVITY_REGIONS.has(collapsed(value));
}

export function normalizeActivityRegions(
  value: unknown,
  legacyValue: unknown,
): string[] {
  const source = Array.isArray(value) ? value : [legacyValue];
  const result: string[] = [];
  for (const item of source) {
    const text = collapsed(item);
    if (text.length === 0 || result.includes(text)) continue;
    result.push(text);
    if (result.length === 3) break;
  }
  return result;
}

export function areValidActivityRegions(value: unknown): boolean {
  if (!Array.isArray(value) || value.length < 1 || value.length > 3) return false;
  if (!value.every((item) => typeof item === "string")) return false;
  const normalized = value.map(collapsed);
  return new Set(normalized).size === normalized.length &&
    normalized.every(isKnownActivityRegion);
}

export function hasLinkedProvider(
  ctx: functions.https.CallableContext,
): boolean {
  const firebase = ctx.auth?.token?.firebase as
    | {sign_in_provider?: string; identities?: Record<string, unknown>}
    | undefined;
  if (!firebase || firebase.sign_in_provider === "anonymous") return false;
  if (firebase.sign_in_provider === "password") return true;
  return Object.keys(firebase.identities ?? {}).length > 0;
}

export function isTrainerProfileComplete(
  profile: FirebaseFirestore.DocumentData,
): boolean {
  const regions = normalizeActivityRegions(
    profile.activityRegions,
    profile.activityRegion,
  );
  return isValidTrainerRealName(profile.realName) &&
    isValidTrainerJobTitleForAffiliation(
      profile.jobTitle,
      profile.affiliationType,
    ) &&
    isValidPrimaryActivity(profile.primaryActivity) &&
    isValidAffiliationType(profile.affiliationType) &&
    regions.length > 0 && regions.every(isKnownActivityRegion);
}

export function tierRank(value: unknown): number {
  const text = String(value ?? "").trim().toLowerCase();
  if (text === "grand prix" || text === "grandprix") return 5;
  if (text === "master") return 4;
  if (text === "pro") return 3;
  if (text === "semi-pro" || text === "semipro") return 2;
  if (text === "amateur") return 1;
  return 0;
}

export function evaluateEarnedTier(args: {
  currentTier: unknown;
  lifetimeQualifiedMemberCount: number;
  accountLinked: boolean;
  profileCompleted: boolean;
}): {tier: EarnedTier; rank: number} {
  let earnedRank = 0;
  if (args.lifetimeQualifiedMemberCount >= 50) {
    earnedRank = 3;
  } else if (args.lifetimeQualifiedMemberCount >= 30) {
    earnedRank = 2;
  }
  const rank = Math.max(tierRank(args.currentTier), earnedRank);
  return {tier: TIER_NAMES[rank], rank};
}
