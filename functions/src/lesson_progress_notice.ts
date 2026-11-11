// 레슨 진행 알림 루트(발송 전 단계).
//
// 레슨을 확정할 때마다 `lesson_progress_notices/{lessonLogId}`에 "보낼 알림" 한 건을 남긴다. 실제 발송
// (알림톡·문자·푸시 등)은 아직 만들지 않았고, 나중에 이 문서를 읽어 보내는 함수를 붙이면 된다.
// - 확정과 같은 트랜잭션에서 만들어 확정과 알림 기록이 어긋나지 않는다.
// - 확정을 취소하면 아직 보내지 않은(`pending`) 알림은 `cancelled`로 바꾼다.
// - 서버(관리자 권한)만 쓰고, 앱은 읽지도 쓰지도 못한다(규칙에 정의하지 않아 기본 거부).

export const LESSON_PROGRESS_NOTICES = "lesson_progress_notices";

export interface LessonProgressNoticeInput {
  trainerId: string;
  memberId: string;
  memberName: string;
  lessonType: string;
  lessonLogId: string;
  status: string;
  // 이번 확정으로 진행 횟수가 늘었는지(소진 확정인지).
  progressChanged: boolean;
  total: number;
  done: number;
  remain: number;
}

// 회원에게 보낼 문장. 예: `홍길동님 PT 레슨 30회 중 10회를 진행 중입니다.`
export function lessonProgressMessage(input: {
  memberName: string;
  lessonType: string;
  total: number;
  done: number;
}): string {
  const type = input.lessonType.trim();
  const subject = `${input.memberName.trim()}님 ${type === "" ? "" : `${type} `}`;
  if (input.total > 0 && input.done >= input.total) {
    return `${subject}레슨 ${input.total}회를 모두 진행했습니다.`;
  }
  return `${subject}레슨 ${input.total}회 중 ${input.done}회를 진행 중입니다.`;
}

// 보낼 알림 문서의 내용. 횟수가 등록되지 않았거나(총 0) 회원 이름이 없으면 만들지 않는다(null).
export function buildLessonProgressNotice(
  input: LessonProgressNoticeInput,
): Record<string, unknown> | null {
  const memberName = input.memberName.trim();
  if (input.total <= 0 || memberName === "") return null;
  return {
    noticeId: input.lessonLogId,
    kind: "lesson_progress",
    trainerId: input.trainerId,
    workspaceType: "personal",
    memberId: input.memberId,
    memberName,
    lessonType: input.lessonType.trim(),
    lessonLogId: input.lessonLogId,
    status: input.status,
    progressChanged: input.progressChanged,
    total: input.total,
    done: input.done,
    remain: input.remain,
    message: lessonProgressMessage({
      memberName,
      lessonType: input.lessonType,
      total: input.total,
      done: input.done,
    }),
    // 보내기 전 상태. 발송 함수가 `sent`/`failed`로 바꾼다.
    state: "pending",
    channel: null,
  };
}

// ---- 계약서 파기 알림(발송 전) ----
// 계약서를 파기하면 회원에게 갈 알림 한 건을 `contract_notices/{계약ID}_void`에 남긴다. 발송은
// 레슨 진행 알림과 같이 나중에 붙인다(서버만 쓰고 앱은 읽지도 쓰지도 못한다).
export const CONTRACT_NOTICES = "contract_notices";

export function contractVoidMessage(input: {
  memberName: string;
  contractNo: string;
}): string {
  const no = input.contractNo.trim();
  return `${input.memberName.trim()}님, ${no === "" ? "" : `${no} `}` +
    "레슨계약서가 파기되었습니다.";
}

export function contractTerminateMessage(input: {
  memberName: string;
  contractNo: string;
}): string {
  const no = input.contractNo.trim();
  return `${input.memberName.trim()}님, ${no === "" ? "" : `${no} `}` +
    "레슨계약서가 해지되었습니다.";
}

// 계약서 해지 알림(발송 전). `contract_notices/{계약ID}_terminate`에 기록만 한다.
export function buildContractTerminateNotice(input: {
  trainerId: string;
  memberId: string;
  memberName: string;
  contractId: string;
  contractNo: string;
  reason: string;
}): Record<string, unknown> | null {
  const memberName = input.memberName.trim();
  if (memberName === "") return null;
  return {
    noticeId: `${input.contractId}_terminate`,
    kind: "contract_terminate",
    trainerId: input.trainerId,
    workspaceType: "personal",
    memberId: input.memberId,
    memberName,
    contractId: input.contractId,
    contractNo: input.contractNo,
    reason: input.reason,
    message: contractTerminateMessage({
      memberName,
      contractNo: input.contractNo,
    }),
    state: "pending",
    channel: null,
  };
}

export function buildContractVoidNotice(input: {
  trainerId: string;
  memberId: string;
  memberName: string;
  contractId: string;
  contractNo: string;
  reason: string;
}): Record<string, unknown> | null {
  const memberName = input.memberName.trim();
  if (memberName === "") return null;
  return {
    noticeId: `${input.contractId}_void`,
    kind: "contract_void",
    trainerId: input.trainerId,
    workspaceType: "personal",
    memberId: input.memberId,
    memberName,
    contractId: input.contractId,
    contractNo: input.contractNo,
    reason: input.reason,
    message: contractVoidMessage({memberName, contractNo: input.contractNo}),
    state: "pending",
    channel: null,
  };
}
