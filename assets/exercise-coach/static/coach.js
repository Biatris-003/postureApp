// ─────────────────────────────────────────────
//  coach.js  —  MediaPipe Pose + Exercise Logic
// ─────────────────────────────────────────────

function loadScript(src) {
  return new Promise((res, rej) => {
    const s = document.createElement('script');
    s.src = src;
    s.onload = res;
    s.onerror = rej;
    document.head.appendChild(s);
  });
}

let pose            = null;
let camera          = null;
let currentEx       = null;
let repCount        = 0;
let phase           = 'start';
let poseReady       = false;

// ── Post rep count to Flutter ──────────────────────────
// Safe to call even if the JavaScript channel isn't set up.
function sendRepCount() {
  if (window.RepCounter) {
    window.RepCounter.postMessage(repCount.toString());
  }
}

// ── EMA angle smoother ──────────────────────────
// Reduces MediaPipe jitter so angles don't fire thresholds on noise spikes.
// alpha=0.25: each frame contributes 25% of new reading, 75% is the running average.
const _smoothed = {};
const EMA_ALPHA = 0.25;

function smoothAngle(key, raw) {
  _smoothed[key] = (_smoothed[key] === undefined)
    ? raw
    : EMA_ALPHA * raw + (1 - EMA_ALPHA) * _smoothed[key];
  return Math.round(_smoothed[key]);
}

function resetSmoother() {
  for (const k in _smoothed) delete _smoothed[k];
}

// IDs that have MediaPipe coaching
const COACHED_IDS = new Set(['circumduction', 'squat', 'side_bend_right', 'sit_to_stand']);

function buildGrid() {
  const grid = document.getElementById('exercise-grid');
  EXERCISES.forEach(ex => {
    const hasCoaching = COACHED_IDS.has(ex.id);
    const card = document.createElement('div');
    card.className = 'ex-card' + (hasCoaching ? '' : ' no-coaching');
    card.innerHTML = `
      <span class="card-icon">${ex.icon || '🏋️'}</span>
      <span class="card-type-pill ${ex.type}">${ex.typeLabel}</span>
      <div class="card-name">${ex.name}</div>
      <div class="card-scenario">${ex.scenario}</div>
      <div class="card-cues">${ex.cues}</div>
      ${!hasCoaching ? '<div class="no-coaching-badge">🚫 NO COACHING FOR THIS EXERCISE YET</div>' : ''}
    `;
    if (hasCoaching) {
      card.addEventListener('click', () => startExercise(ex));
    }
    grid.appendChild(card);
  });
}
// ── Angle math ─────────────────────────────────
function getAngle(A, B, C) {
  if (!A || !B || !C) return 0;
  const BAx = A.x - B.x, BAy = A.y - B.y;
  const BCx = C.x - B.x, BCy = C.y - B.y;
  const dot  = BAx * BCx + BAy * BCy;
  const magA = Math.sqrt(BAx * BAx + BAy * BAy);
  const magC = Math.sqrt(BCx * BCx + BCy * BCy);
  if (magA * magC === 0) return 0;
  return Math.round(Math.acos(Math.max(-1, Math.min(1, dot / (magA * magC)))) * (180 / Math.PI));
}

// ── Side-bend trunk tilt ────────────────────────────────────────────────────
// Measures lateral trunk tilt using the angle at the SHOULDER VERTEX between
// the trunk line (hip→shoulder) and the shoulder line (shoulder→opposite shoulder).
//
//  side_bend_right : vertex = left  shoulder, landmarks 23 → 11 → 12
//    Upright ≈ 90°.  Bending RIGHT opens the angle → 101–106° target.
//
//  side_bend_left  : vertex = right shoulder, landmarks 24 → 12 → 11
//    Upright ≈ 90°.  Bending LEFT  opens the angle → 101–106° target.
//
// Body-relative vectors: immune to whole-body lateral shift in frame.
function getSideBendTrunkAngle(lm, exId) {
  const lShoulder = lm[11], rShoulder = lm[12];
  const lHip = lm[23],      rHip      = lm[24];
  if (!lShoulder || !rShoulder || !lHip || !rHip) return 90;

  // Choose vertex based on direction
  const hipPt    = (exId === 'side_bend_left') ? rHip      : lHip;
  const vertexPt = (exId === 'side_bend_left') ? rShoulder : lShoulder;
  const tipPt    = (exId === 'side_bend_left') ? lShoulder : rShoulder;

  // Vector A: hip → vertex (trunk direction)
  const ax = vertexPt.x - hipPt.x, ay = vertexPt.y - hipPt.y;
  // Vector B: vertex → opposite shoulder (shoulder line)
  const bx = tipPt.x - vertexPt.x,  by = tipPt.y - vertexPt.y;

  const dot  = ax * bx + ay * by;
  const magA = Math.sqrt(ax * ax + ay * ay);
  const magB = Math.sqrt(bx * bx + by * by);
  if (magA * magB === 0) return 90;

  return Math.round(
    Math.acos(Math.max(-1, Math.min(1, dot / (magA * magB)))) * (180 / Math.PI)
  );
}

function getArmAngle(shoulder, wrist) {
  if (!shoulder || !wrist) return 0;
  const dx = wrist.x - shoulder.x;
  const dy = wrist.y - shoulder.y;
  let angle = Math.atan2(dy, dx) * 180 / Math.PI;
  if (angle < 0) angle += 360;
  return angle;
}

// ── Start exercise ──────────────────────────────
async function startExercise(ex) {
  currentEx  = ex;
  repCount   = 0;
  phase      = 'start';
  resetSmoother();

  // Reset stateful exercises — wipe all _state keys to initial values
  if (ex._state) {
    ex._state.inDown     = false;
    ex._state.repCount   = 0;
    ex._state.downFrames = 0;
    ex._state.upFrames   = 0;
  }

  // Init circumduction circle state
  if (ex.id === 'circumduction') {
    ex._circleState = {
      rightPrevAngle: null,
      leftPrevAngle:  null,
      rightCrossedZero: false,
      leftCrossedZero:  false,
    };
  }

  document.getElementById('coach-title').textContent    = ex.name;
  document.getElementById('coach-subtitle').textContent = ex.cues;
  document.getElementById('rep-count').textContent      = '0';
  setPhaseLabel('start');
  setStatus('neutral', 'Waiting for pose...');
  setFeedback([{ msg: 'Get into position to begin', type: 'neutral' }]);
  clearAngles();

  // ── Send initial rep count (0) to Flutter ──
  sendRepCount();

  document.getElementById('screen-select').classList.remove('active');
  document.getElementById('screen-coach').classList.add('active');

  await initPose();
}

// ── Go back ─────────────────────────────────────
function goBack() {
  if (camera) { try { camera.stop(); } catch(e) {} camera = null; }
  pose      = null;
  poseReady = false;
  document.getElementById('screen-coach').classList.remove('active');
  document.getElementById('screen-select').classList.add('active');
  document.getElementById('no-pose').style.display = '';
}

// ── Init MediaPipe ──────────────────────────────
async function initPose() {
  if (typeof Pose === 'undefined') {
    setStatus('neutral', 'Loading pose model...');
    await loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js');
    await loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/drawing_utils/drawing_utils.js');
    await loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/pose/pose.js');
  }

  const video  = document.getElementById('video');
  const canvas = document.getElementById('overlay');
  const ctx    = canvas.getContext('2d');

  pose = new Pose({
    locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/pose/${file}`
  });

  pose.setOptions({
    modelComplexity:        1,
    smoothLandmarks:        true,
    enableSegmentation:     false,
    minDetectionConfidence: 0.5,
    minTrackingConfidence:  0.5,
  });

  pose.onResults((results) => onResults(results, ctx, canvas, video));
  await pose.initialize();
  setStatus('neutral', 'Model ready — starting camera...');

  camera = new Camera(video, {
    onFrame: async () => { if (pose) await pose.send({ image: video }); },
    width:  640,
    height: 480,
  });

  camera.start();
}

// ── Process each frame ──────────────────────────
function onResults(results, ctx, canvas, video) {
  canvas.width  = video.videoWidth  || 640;
  canvas.height = video.videoHeight || 480;
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  if (!results.poseLandmarks || results.poseLandmarks.length === 0) {
    poseReady = false;
    document.getElementById('no-pose').style.display = '';
    setStatus('neutral', 'Stand in frame to begin');
    return;
  }

  poseReady = true;
  document.getElementById('no-pose').style.display = 'none';

  const lm = results.poseLandmarks;

  drawConnectors(ctx, lm, POSE_CONNECTIONS, {
    color: 'rgba(255, 255, 255, 0.15)',
    lineWidth: 2,
  });
  drawLandmarks(ctx, lm, {
    color: '#00e5ff',
    fillColor: 'rgba(0, 229, 255, 0.2)',
    lineWidth: 1,
    radius: 4,
  });

  if (currentEx) processExercise(lm, ctx, canvas);
}

// ── Per-frame exercise logic ────────────────────
function processExercise(lm, ctx, canvas) {
  const ex = currentEx;

  // Compute angles and apply EMA smoothing
  const angles = {};
  ex.angles.forEach(a => {
    let raw;
    if (a.key === 'trunk' && (ex.id === 'side_bend_right' || ex.id === 'side_bend_left')) {
      // Use body-relative lateral tilt function instead of generic 3-point angle
      raw = getSideBendTrunkAngle(lm, ex.id);
    } else {
      const [i1, i2, i3] = a.landmarks;
      raw = getAngle(lm[i1], lm[i2], lm[i3]);
    }
    angles[a.key] = smoothAngle(a.key, raw);
  });

  updateAnglesDisplay(angles, ex);
  drawAngleOverlays(ctx, canvas, lm, angles, ex);

  // ── Rep counting ──
  if (ex.onFrame) {
    const newCount = ex.onFrame(angles);
    if (newCount > repCount) {
      repCount = newCount;
      document.getElementById('rep-count').textContent = repCount;
      sendRepCount();   // <── NEW: post updated count
    }

  } else if (ex.id === 'circumduction') {
    const state = ex._circleState;
    const rightArmAngle = getArmAngle(lm[12], lm[16]);
    const leftArmAngle  = getArmAngle(lm[11], lm[15]);

    let repCompleted = false;

    if (state.rightPrevAngle !== null) {
      if (state.rightPrevAngle > 270 && rightArmAngle < 90 && !state.rightCrossedZero) {
        state.rightCrossedZero = true;
      }
      if (state.rightCrossedZero && rightArmAngle < 30 && state.rightPrevAngle < 40) {
        state.rightCrossedZero = false;
        repCompleted = true;
      }
    }

    if (state.leftPrevAngle !== null) {
      if (state.leftPrevAngle > 270 && leftArmAngle < 90 && !state.leftCrossedZero) {
        state.leftCrossedZero = true;
      }
      if (state.leftCrossedZero && leftArmAngle < 30 && state.leftPrevAngle < 40) {
        state.leftCrossedZero = false;
        repCompleted = true;
      }
    }

    state.rightPrevAngle = rightArmAngle;
    state.leftPrevAngle  = leftArmAngle;

    if (repCompleted) {
      repCount++;
      document.getElementById('rep-count').textContent = repCount;
      setPhaseLabel('up');
      setFeedback([{ msg: 'Full circle completed!', type: 'good' }]);
      sendRepCount();   // <── NEW
    } else {
      setPhaseLabel('down');
    }

  } else {
    const repAngle = angles[ex.repJoint];

    if (!ex.isHold) {
      if ((phase === 'start' || phase === 'up') && repAngle < ex.downAngle) {
        phase = 'down';
        setPhaseLabel('down');
      } else if (phase === 'down' && repAngle > ex.upAngle) {
        phase = 'up';
        repCount++;
        document.getElementById('rep-count').textContent = repCount;
        setPhaseLabel('up');
        sendRepCount();   // <── NEW
      }
    } else {
      if (phase === 'start' && repAngle < ex.downAngle) {
        phase = 'hold';
        setPhaseLabel('hold');
      } else if (phase === 'hold' && repAngle > ex.upAngle) {
        phase = 'start';
        setPhaseLabel('start');
      }
    }
  }

  // ── Coaching rules ──
  const triggered = ex.rules.filter(r => r.check(angles));

  if (triggered.length > 0) {
    const first = triggered[0];
    setStatus(first.type === 'good' ? 'good' : 'bad', first.msg);
    setFeedback(triggered.map(r => ({ msg: r.msg, type: r.type })));
  } else if (ex.id !== 'circumduction') {
    const idleMsg = phase === 'down' ? 'Hold position...' : 'Looking good — keep going!';
    setStatus('good', idleMsg);
    setFeedback([{ msg: idleMsg, type: 'good' }]);
  }
}

// ── Draw angle values on canvas ─────────────────
function drawAngleOverlays(ctx, canvas, lm, angles, ex) {
  ex.angles.slice(0, 2).forEach(a => {
    const [, i2] = a.landmarks;
    const joint  = lm[i2];
    if (!joint) return;

    const x   = joint.x * canvas.width;
    const y   = joint.y * canvas.height;
    const val = angles[a.key];

    const minVal  = a.min !== undefined ? a.min : ex.downAngle;
    const maxVal  = a.max !== undefined ? a.max : ex.upAngle;
    const inRange = val >= minVal && val <= maxVal;
    const color   = inRange ? '#00d68f' : '#ff5252';

    ctx.save();
    ctx.font        = 'bold 18px JetBrains Mono, monospace'; /* was 13px */
    ctx.fillStyle   = color;
    ctx.strokeStyle = 'rgba(0,0,0,0.85)';
    ctx.lineWidth   = 4;                                      /* was 3 */
    ctx.strokeText(`${val}°`, x + 12, y - 10);
    ctx.fillText(`${val}°`, x + 12, y - 10);
    ctx.restore();
  });
}

// ── UI helpers ──────────────────────────────────
function setStatus(type, msg) {
  const dot = document.getElementById('status-dot');
  dot.className = 'status-dot ' + type;
  document.getElementById('status-text').textContent = msg;
}

function setPhaseLabel(p) {
  const map = {
    start: ['start', 'Get into position'],
    up:    ['up',    'Rep complete!'],
    down:  ['down',  'Keep going...'],
    hold:  ['hold',  'Hold position'],
  };
  const [cls, label] = map[p] || map.start;
  document.getElementById('phase-label').innerHTML =
    `<span class="phase-badge ${cls}">${label}</span>`;
}

function updateAnglesDisplay(angles, ex) {
  const container = document.getElementById('angles-display');
  container.innerHTML = '';

  ex.angles.forEach(a => {
    const val     = angles[a.key] || 0;
    const minVal  = a.min !== undefined ? a.min : ex.downAngle;
    const maxVal  = a.max !== undefined ? a.max : ex.upAngle;
    const inRange = val >= minVal && val <= maxVal;
    const color   = inRange ? '#00d68f' : (val < minVal ? '#00e5ff' : '#ff5252');

    container.innerHTML += `
      <div class="angle-row">
        <span class="angle-name">${a.name}</span>
        <span class="angle-val" style="color:${color}">${val}°</span>
      </div>`;
  });
}

function setFeedback(items) {
  const list = document.getElementById('feedback-list');
  list.innerHTML = '';
  items.forEach(f => {
    const icon = f.type === 'good' ? '✅' : f.type === 'warn' ? '⚠️' : 'ℹ️';
    const cls  = f.type === 'good' ? 'fb-good' : f.type === 'warn' ? 'fb-warn' : 'fb-neutral';
    list.innerHTML += `<li class="${cls}">${icon} ${f.msg}</li>`;
  });
}

function clearAngles() {
  document.getElementById('angles-display').innerHTML = '';
}

// ── Boot ────────────────────────────────────────
buildGrid();