// 아나토미 바디맵 부위 영역 변환기.
// tool/anatomy/src/*.svg(일러스트 원본)의 조각을 부위·좌우로 매핑해
// assets/anatomy/body_map.json 으로 내보낸다. 실행: node tool/anatomy/build_zones.cjs
//
// 좌우는 항상 "그림 속 사람" 기준이다. 앞면은 화면 왼쪽이 사람의 오른쪽,
// 뒷면은 화면 왼쪽이 사람의 왼쪽이다. 이름 끝에 _l/_r 이 없는 부위는
// 가운데선에서 좌우로 자른다(abs 는 좌우 구분 없이 center).
const fs = require('fs');
const path = require('path');

const SRC = path.join(__dirname, 'src');
const OUT = path.join(__dirname, '..', '..', 'assets', 'anatomy', 'body_map.json');

const VIEWS = [
  {
    key: 'male_front', view: 'front', file: '남자전면.svg',
    map: {
      chest: 'chest', abs: 'abs',
      oblique_R_3_: 'oblique_r', oblique_R_1_: 'oblique_l',
      shoulder_R_7_: 'delt_front_r', shoulder_R_4_: 'delt_side_r',
      shoulder_R_3_: 'delt_front_l', shoulder_R_1_: 'delt_side_l',
      bicep_R_1_: 'biceps_r', bicep_R_2_: 'biceps_l',
      forearm_R_10_: 'forearm_r', forearm_R_7_: 'forearm_l',
      forearm_R_3_: 'hand_r', forearm_R_1_: 'hand_l',
      forearm_R_4_: 'foot_r', forearm_R_2_: 'foot_l',
      hip_R_3_: 'tfl_r', hip_R_1_: 'tfl_l',
      hip_R_2_: 'iliopsoas_r', hip_R: 'iliopsoas_l',
      quad_R_1_: 'quad_r', quad_R_2_: 'quad_l',
      quad_R_3_: 'adductor_r', quad_R_4_: 'adductor_l',
      calf_R_1_: 'tibialis_r', calf_R_2_: 'tibialis_l',
    },
  },
  {
    key: 'male_back', view: 'back', file: '남자후면.svg',
    map: {
      chest_1_: 'trapezius', chest: 'upper_back', abs: 'lower_back', oblique_R_2_: 'lat',
      shoulder_R_7_: 'delt_rear_l', shoulder_R_4_: 'delt_side_l',
      shoulder_R_2_: 'delt_rear_r', shoulder_R_3_: 'delt_side_r',
      bicep_R_1_: 'triceps_l', bicep_R: 'triceps_r',
      forearm_R_10_: 'forearm_l', forearm_R: 'forearm_r',
      forearm_R_3_: 'hand_l', forearm_R_1_: 'hand_r',
      forearm_R_4_: 'foot_l', forearm_R_2_: 'foot_r',
      hip_R_4_: 'glute', hip_R_3_: 'glute_med_l', hip_R_2_: 'glute_med_r',
      quad_R_1_: 'hamstring_l', quad_R: 'hamstring_r',
      quad_R_3_: 'adductor_l', quad_R_2_: 'adductor_r',
      calf_R_1_: 'calf_l', calf_R: 'calf_r',
    },
  },
  {
    key: 'female_front', view: 'front', file: '여자전면.svg',
    map: {
      chest: 'chest', chest_1_: 'EXCLUDE', abs: 'abs',
      oblique_R_1_: 'oblique_r', oblique_R: 'oblique_l',
      // 화면 왼쪽(사람의 오른쪽): 안쪽 쐐기 = 전면, 바깥 띠 = 측면.
      shoulder_R_2_: 'delt_front_r', shoulder_R_1_: 'delt_side_r',
      // 화면 오른쪽(사람의 왼쪽): 원본은 어깨 전체 조각(shoulder_R) 위에 가는 띠
      // (shoulder_R_3_)가 겹쳐 있어, 띠가 지나는 선으로 안쪽/바깥을 나눈다.
      shoulder_R: {
        splitLine: [[364.4, 147.8], [397.6, 208.6]],
        outsidePoint: [410, 180],
        inner: 'delt_front_l',
        outer: 'delt_side_l',
      },
      shoulder_R_3_: 'EXCLUDE',
      bicep_R_1_: 'biceps_r', bicep_R: 'biceps_l',
      forearm_R_7_: 'forearm_r', forearm_R: 'forearm_l',
      forearm_R_3_: 'hand_r', forearm_R_1_: 'hand_l',
      forearm_R_5_: 'foot_r', forearm_R_2_: 'foot_l',
      hip_R_8_: 'iliopsoas_r', hip_R: 'iliopsoas_l',
      hip_R_2_: 'tfl_r', hip_R_4_: 'tfl_l',
      quad_R_1_: 'quad_r', quad_R: 'quad_l',
      quad_R_4_: 'adductor',
      calf_R_1_: 'tibialis_r', calf_R: 'tibialis_l',
    },
  },
  {
    key: 'female_back', view: 'back', file: '여자후면-1.svg',
    map: {
      chest_1_: 'trapezius', chest: 'upper_back', abs: 'lower_back', oblique_R_2_: 'lat',
      shoulder_R_1_: 'delt_rear_l', shoulder_R_2_: 'delt_rear_r',
      bicep_R_2_: 'triceps_l', bicep_R: 'triceps_r',
      forearm_R_16_: 'forearm_l', forearm_R: 'forearm_r',
      forearm_R_11_: 'hand_l', forearm_R_1_: 'hand_r',
      forearm_R_4_: 'foot_l', forearm_R_2_: 'foot_r',
      hip_R_4_: 'glute', hip_R_3_: 'glute_med_l', hip_R_2_: 'glute_med_r',
      quad_R_4_: 'hamstring_l', quad_R: 'hamstring_r',
      quad_R_1_: 'adductor_l', quad_R_2_: 'adductor_r',
      calf_R_2_: 'calf_l', calf_R: 'calf_r',
    },
  },
];

// 같은 부위가 겹칠 때 위에 놓을 부위(숫자가 클수록 위). 나머지는 면적이 작을수록 위.
const PRIORITY = { trapezius: 1 };
const ONE_SIDE_NAMES = new Set(['abs']);

function parseNumbers(text) {
  return (text.match(/-?\d*\.?\d+(?:e-?\d+)?/g) || []).map(Number);
}

function flattenCubic(p0, p1, p2, p3, steps = 8) {
  const pts = [];
  for (let i = 1; i <= steps; i++) {
    const t = i / steps;
    const u = 1 - t;
    pts.push([
      u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
      u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1],
    ]);
  }
  return pts;
}

function parsePath(d) {
  const tokens = d.match(/[MmLlHhVvCcZz]|-?\d*\.?\d+(?:e-?\d+)?/g) || [];
  const pts = [];
  let i = 0;
  let cmd = '';
  let cur = [0, 0];
  let start = [0, 0];
  const num = () => Number(tokens[i++]);
  const isNum = () => i < tokens.length && !/^[A-Za-z]$/.test(tokens[i]);
  while (i < tokens.length) {
    if (/^[A-Za-z]$/.test(tokens[i])) cmd = tokens[i++];
    switch (cmd) {
      case 'M': case 'm': {
        const rel = cmd === 'm';
        let first = true;
        while (isNum()) {
          const x = num(); const y = num();
          cur = rel ? [cur[0] + x, cur[1] + y] : [x, y];
          if (first) start = cur;
          pts.push(cur);
          first = false;
        }
        cmd = rel ? 'l' : 'L';
        break;
      }
      case 'L': case 'l': {
        const rel = cmd === 'l';
        while (isNum()) {
          const x = num(); const y = num();
          cur = rel ? [cur[0] + x, cur[1] + y] : [x, y];
          pts.push(cur);
        }
        break;
      }
      case 'H': case 'h':
        while (isNum()) { const x = num(); cur = [cmd === 'h' ? cur[0] + x : x, cur[1]]; pts.push(cur); }
        break;
      case 'V': case 'v':
        while (isNum()) { const y = num(); cur = [cur[0], cmd === 'v' ? cur[1] + y : y]; pts.push(cur); }
        break;
      case 'C': case 'c': {
        const rel = cmd === 'c';
        while (isNum()) {
          const v = [num(), num(), num(), num(), num(), num()];
          const o = rel ? cur : [0, 0];
          const p1 = [o[0] + v[0], o[1] + v[1]];
          const p2 = [o[0] + v[2], o[1] + v[3]];
          const p3 = [o[0] + v[4], o[1] + v[5]];
          pts.push(...flattenCubic(cur, p1, p2, p3));
          cur = p3;
        }
        break;
      }
      case 'Z': case 'z':
        cur = start;
        break;
      default:
        throw new Error('unsupported path command: ' + cmd);
    }
  }
  return pts;
}

function elementsOf(svg) {
  const out = [];
  const re = /<(polygon|polyline|path)\b([^>]*?)\/?>/gs;
  let m;
  while ((m = re.exec(svg))) {
    const attrs = m[2];
    const id = /\bid="([^"]+)"/.exec(attrs);
    if (!id) continue;
    let pts;
    if (m[1] === 'path') {
      const d = /\bd="([^"]+)"/.exec(attrs);
      if (!d) continue;
      pts = parsePath(d[1]);
    } else {
      const p = /\bpoints="([^"]+)"/.exec(attrs);
      if (!p) continue;
      const n = parseNumbers(p[1]);
      pts = [];
      for (let k = 0; k + 1 < n.length; k += 2) pts.push([n[k], n[k + 1]]);
    }
    if (pts.length >= 3) out.push({ id: id[1], pts });
  }
  return out;
}

function area(pts) {
  let a = 0;
  for (let i = 0; i < pts.length; i++) {
    const [x1, y1] = pts[i];
    const [x2, y2] = pts[(i + 1) % pts.length];
    a += x1 * y2 - x2 * y1;
  }
  return Math.abs(a) / 2;
}

// Sutherland–Hodgman: keepLeft 이면 x <= mid, 아니면 x >= mid 쪽만 남긴다.
function clipX(pts, mid, keepLeft) {
  const inside = (p) => (keepLeft ? p[0] <= mid : p[0] >= mid);
  const cross = (a, b) => {
    const t = (mid - a[0]) / (b[0] - a[0]);
    return [mid, a[1] + t * (b[1] - a[1])];
  };
  const out = [];
  for (let i = 0; i < pts.length; i++) {
    const cur = pts[i];
    const prev = pts[(i + pts.length - 1) % pts.length];
    if (inside(cur)) {
      if (!inside(prev)) out.push(cross(prev, cur));
      out.push(cur);
    } else if (inside(prev)) {
      out.push(cross(prev, cur));
    }
  }
  return out;
}

// 직선 a→b 의 한쪽(refPoint 와 같은 쪽 또는 반대쪽)만 남긴다.
function clipLine(pts, a, b, refPoint, keepRefSide) {
  const side = (p) => (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]);
  const refSign = Math.sign(side(refPoint));
  const inside = (p) => (keepRefSide ? Math.sign(side(p)) * refSign >= 0 : Math.sign(side(p)) * refSign <= 0);
  const cross = (p, q) => {
    const sp = side(p);
    const sq = side(q);
    const t = sp / (sp - sq);
    return [p[0] + t * (q[0] - p[0]), p[1] + t * (q[1] - p[1])];
  };
  const out = [];
  for (let i = 0; i < pts.length; i++) {
    const cur = pts[i];
    const prev = pts[(i + pts.length - 1) % pts.length];
    if (inside(cur)) {
      if (!inside(prev)) out.push(cross(prev, cur));
      out.push(cur);
    } else if (inside(prev)) {
      out.push(cross(prev, cur));
    }
  }
  return out;
}

function round1(n) { return Math.round(n * 10) / 10; }

const maps = {};
for (const v of VIEWS) {
  const svg = fs.readFileSync(path.join(SRC, v.file), 'utf8');
  const els = elementsOf(svg);
  const byId = new Map(els.map((e) => [e.id, e]));
  for (const id of Object.keys(v.map)) {
    if (!byId.has(id)) throw new Error(`${v.key}: SVG에 ${id} 조각이 없습니다`);
  }
  const absEl = byId.get(Object.keys(v.map).find((k) => v.map[k] === 'abs' || v.map[k] === 'lower_back'));
  const xs = absEl.pts.map((p) => p[0]);
  const mid = round1((Math.min(...xs) + Math.max(...xs)) / 2);
  const screenLeftSide = v.view === 'front' ? 'right' : 'left';
  const screenRightSide = v.view === 'front' ? 'left' : 'right';

  const zones = [];
  const unmapped = [];
  for (const el of els) {
    const name = v.map[el.id];
    if (name === undefined) { unmapped.push(el.id); continue; }
    if (name === 'EXCLUDE') continue;
    if (typeof name === 'object') {
      const [a, b] = name.splitLine;
      const outerPts = clipLine(el.pts, a, b, name.outsidePoint, true);
      const innerPts = clipLine(el.pts, a, b, name.outsidePoint, false);
      for (const [pts, full] of [[outerPts, name.outer], [innerPts, name.inner]]) {
        const m2 = /^(.*)_(l|r)$/.exec(full);
        if (pts.length >= 3) zones.push({ part: m2[1], side: m2[2] === 'l' ? 'left' : 'right', pts });
      }
      continue;
    }
    const m = /^(.*)_(l|r)$/.exec(name);
    if (m) {
      zones.push({ part: m[1], side: m[2] === 'l' ? 'left' : 'right', pts: el.pts });
    } else if (ONE_SIDE_NAMES.has(name)) {
      zones.push({ part: name, side: 'center', pts: el.pts });
    } else {
      const leftHalf = clipX(el.pts, mid, true);
      const rightHalf = clipX(el.pts, mid, false);
      if (leftHalf.length >= 3) zones.push({ part: name, side: screenLeftSide, pts: leftHalf });
      if (rightHalf.length >= 3) zones.push({ part: name, side: screenRightSide, pts: rightHalf });
    }
  }
  if (unmapped.length) throw new Error(`${v.key}: 매핑 없는 조각 ${unmapped.join(', ')}`);

  zones.sort((a, b) => {
    const pa = PRIORITY[a.part] || 0;
    const pb = PRIORITY[b.part] || 0;
    if (pa !== pb) return pa - pb;
    return area(b.pts) - area(a.pts);
  });

  maps[v.key] = {
    view: v.view,
    image: `assets/anatomy/${v.key}.png`,
    midline: mid,
    zones: zones.map((z) => ({
      part: z.part,
      side: z.side,
      pts: z.pts.flatMap((p) => [round1(p[0]), round1(p[1])]),
    })),
  };
  console.log(v.key, 'zones', zones.length, 'mid', mid);
}

const json = { viewBox: { w: 595.3, h: 841.9 }, maps };
fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(json));
console.log('wrote', OUT, fs.statSync(OUT).size, 'bytes');
