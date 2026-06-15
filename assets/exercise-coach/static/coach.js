// ─────────────────────────────────────────────
//  coach.js  —  MediaPipe Pose + Exercise Logic
// ─────────────────────────────────────────────

// Dynamically load MediaPipe from CDN
function loadScript(src) {
  return new Promise((res, rej) => {
    const s = document.createElement('script');
    s.src = src;
    s.onload = res;
    s.onerror = rej;
    document.head.appendChild(s);
  });
}
let badPostureStart = null;
let alertTriggered = false;
let pose        = null;
let camera      = null;
let currentEx   = null;
let repCount    = 0;
let phase       = 'start';   // 'start' | 'down' | 'up' | 'hold'
let poseReady   = false;

// RULA Assessment state
let isRULAMode  = false;
let rulaCamera  = null;
let rulaPoseReady = false;

// ── Build exercise selection grid ──────────────
function buildGrid() {
  const grid = document.getElementById('exercise-grid');
  EXERCISES.forEach(ex => {
    const card = document.createElement('div');
    card.className = 'ex-card';
    card.innerHTML = `
      <span class="badge ${ex.type}">${ex.typeLabel}</span>
      <h3>${ex.name}</h3>
      <p class="scenario">${ex.scenario}</p>
      <p class="cues">${ex.cues}</p>
    `;
    card.addEventListener('click', () => {
      // Route to RULA Assessment or regular exercise
      if (ex.id === 'rula_assessment') {
        startRULAAssessment();
      } else {
        startExercise(ex);
      }
    });
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

// Calculate the angle of the arm relative to the shoulder (for circle tracking)
function getArmAngle(shoulder, wrist) {
  if (!shoulder || !wrist) return 0;
  // Calculate angle of the vector from shoulder to wrist (0° = pointing right, 90° = up, etc.)
  const dx = wrist.x - shoulder.x;
  const dy = wrist.y - shoulder.y;
  let angle = Math.atan2(dy, dx) * 180 / Math.PI;
  // Normalize to 0-360
  if (angle < 0) angle += 360;
  return angle;
}

// Track circle completion using arm angle (0-360°)
function trackCircleCompletion(prevAngle, currentAngle, circleState) {
  if (prevAngle === null) return false;
  
  // Detect when we cross from high angle to low angle (completing a full circle)
  // A full circle is detected when we go from near 360° back to near 0°
  const crossedZero = (prevAngle > 270 && currentAngle < 90);
  
  if (crossedZero && !circleState.crossedZeroThisCircle) {
    circleState.crossedZeroThisCircle = true;
  }
  
  // If we've crossed zero and now we're back to starting position, count a rep
  if (circleState.crossedZeroThisCircle && currentAngle < 20 && prevAngle < 30) {
    circleState.crossedZeroThisCircle = false;
    return true;
  }
  
  return false;
}

function scoreUpperArm(angle){

    if(angle < 20) return 1;
    if(angle < 45) return 2;
    if(angle < 90) return 3;
    return 4;
}

function scoreForearm(angle){

    if(angle >= 70 && angle <= 110)
        return 1;

    return 2;
}

function scoreWrist(angle){

    if(angle >= 85 && angle <= 95)
        return 1;

    return 2;
}

function scoreNeck(angle){

    if(angle < 10) return 1;
    if(angle < 20) return 2;
    if(angle < 45) return 3;

    return 4;
}

function scoreTrunk(angle){

    if(angle < 5) return 1;
    if(angle < 20) return 2;
    if(angle < 60) return 3;

    return 4;
}

function calcUpperArm(lm){
  // Upper arm angle: shoulder -> elbow -> wrist
  return getAngle(lm[12], lm[14], lm[16]);
}

function calcNeck(lm){
  // Neck angle: nose -> shoulder -> hip
  return getAngle(lm[0], lm[12], lm[24]);
}

function calcTrunk(lm){
  // Trunk angle: shoulder -> hip -> knee
  return getAngle(lm[12], lm[24], lm[26]);
}

function calculateRula(lm){

    const upperArm =
        calcUpperArm(lm);

    const forearm =
        getAngle(lm[12],lm[14],lm[16]);

    const wrist =
        getAngle(lm[14],lm[16],lm[20] || lm[18]);

    const neck =
        calcNeck(lm);

    const trunk =
        calcTrunk(lm);

    const total =
        scoreUpperArm(upperArm)
      + scoreForearm(forearm)
      + scoreWrist(wrist)
      + scoreNeck(neck)
      + scoreTrunk(trunk);

    return Math.min(7,
        Math.round(total/2)
    );
}

// ── Start exercise ──────────────────────────────
// ── Start exercise ──────────────────────────────
async function startExercise(ex) {
  currentEx   = ex;
  repCount    = 0;
  phase       = 'start';
  
  // Reset exercise-specific state for sit_to_stand and side bends
  if (ex._state) {
    ex._state.inDown = false;
    ex._state.repCount = 0;
  }
  
  // Initialize circumduction circle tracking state
  if (ex.id === 'circumduction') {
    if (!ex._circleState) {
      ex._circleState = {};
    }
    // Track arm angles for circle detection
    ex._circleState.rightPrevAngle = null;
    ex._circleState.leftPrevAngle = null;
    ex._circleState.rightCrossedZero = false;
    ex._circleState.leftCrossedZero = false;
    ex._circleState.rightCompletedReps = 0;
    ex._circleState.leftCompletedReps = 0;
  }

  document.getElementById('coach-title').textContent   = ex.name;
  document.getElementById('coach-subtitle').textContent = ex.cues;
  document.getElementById('rep-count').textContent     = '0';
  setPhaseLabel('start');
  setStatus('neutral', 'Waiting for pose...');
  setFeedback([{ msg: 'Get into position to begin', type: 'neutral' }]);
  clearAngles();

  document.getElementById('screen-select').classList.remove('active');
  document.getElementById('screen-coach').classList.add('active');

  await initPose();
}

// ── Go back ─────────────────────────────────────
function goBack() {
  if (camera) { try { camera.stop(); } catch(e) {} camera = null; }
  if (rulaCamera) { try { rulaCamera.stop(); } catch(e) {} rulaCamera = null; }
  pose      = null;
  poseReady = false;
  rulaPoseReady = false;
  isRULAMode = false;
  document.getElementById('screen-coach').classList.remove('active');
  document.getElementById('screen-rula').classList.remove('active');
  document.getElementById('screen-select').classList.add('active');
  document.getElementById('no-pose').style.display = '';
  document.getElementById('no-pose-rula').style.display = '';
}

// ── Init MediaPipe Pose ─────────────────────────
async function initPose() {
  // Load libraries if not already present
  if (typeof Pose === 'undefined') {
    setStatus('neutral', 'Loading pose model...');
    await loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js');
    await loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/drawing_utils/drawing_utils.js');
    await loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/pose/pose.js');
  }

  const video   = document.getElementById('video');
  const canvas  = document.getElementById('overlay');
  const ctx     = canvas.getContext('2d');

  pose = new Pose({
    locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/pose/${file}`
  });

  pose.setOptions({
    modelComplexity: 1,
    smoothLandmarks: true,
    enableSegmentation: false,
    minDetectionConfidence: 0.5,
    minTrackingConfidence: 0.5,
  });

  pose.onResults((results) => onResults(results, ctx, canvas, video));

  await pose.initialize();
  setStatus('neutral', 'Model ready — starting camera...');

  camera = new Camera(video, {
    onFrame: async () => {
      if (pose) await pose.send({ image: video });
    },
    width: 640,
    height: 480,
  });

  camera.start();
}

// ── Start RULA Assessment ──────────────────────
async function startRULAAssessment() {
  isRULAMode = true;
  rulaAssessment.reset();

  document.getElementById('rula-reps-count').textContent = '0';
  document.getElementById('rula-posture-timer').innerHTML = '<div class="timer-value">0s</div><div class="timer-label">/ 10s Good Posture</div>';
  setRULAStatus('neutral', 'Waiting for pose...');
  setRULAFeedback([{ msg: 'Sit naturally and maintain good posture', type: 'neutral' }]);

  document.getElementById('screen-select').classList.remove('active');
  document.getElementById('screen-rula').classList.add('active');

  await initRULAPose();
}

// ── Init RULA Pose Detection ────────────────────
async function initRULAPose() {
  // Load libraries if not already present
  if (typeof Pose === 'undefined') {
    setRULAStatus('neutral', 'Loading pose model...');
    await loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/camera_utils/camera_utils.js');
    await loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/drawing_utils/drawing_utils.js');
    await loadScript('https://cdn.jsdelivr.net/npm/@mediapipe/pose/pose.js');
  }

  const video   = document.getElementById('video-rula');
  const canvas  = document.getElementById('overlay-rula');
  const ctx     = canvas.getContext('2d');

  const rulaPose = new Pose({
    locateFile: (file) => `https://cdn.jsdelivr.net/npm/@mediapipe/pose/${file}`
  });

  rulaPose.setOptions({
    modelComplexity: 1,
    smoothLandmarks: true,
    enableSegmentation: false,
    minDetectionConfidence: 0.5,
    minTrackingConfidence: 0.5,
  });

  rulaPose.onResults((results) => onRULAResults(results, ctx, canvas, video, rulaPose));

  await rulaPose.initialize();
  setRULAStatus('neutral', 'Model ready — starting camera...');

  rulaCamera = new Camera(video, {
    onFrame: async () => {
      if (rulaPose) await rulaPose.send({ image: video });
    },
    width: 640,
    height: 480,
  });

  rulaCamera.start();
}

// ── Process RULA Frames ─────────────────────────
function onRULAResults(results, ctx, canvas, video, rulaPose) {
  canvas.width  = video.videoWidth  || 640;
  canvas.height = video.videoHeight || 480;
  ctx.clearRect(0, 0, canvas.width, canvas.height);

  if (!results.poseLandmarks || results.poseLandmarks.length === 0) {
    rulaPoseReady = false;
    document.getElementById('no-pose-rula').style.display = '';
    setRULAStatus('neutral', 'Sit in frame to begin');
    return;
  }

  rulaPoseReady = true;
  document.getElementById('no-pose-rula').style.display = 'none';

  const lm = results.poseLandmarks;

  // First, calculate posture to know which joints are good/bad
  const posture = {
    upperArm: calcUpperArm(lm),
    forearm: getAngle(lm[12], lm[14], lm[16]),
    wrist: getAngle(lm[14], lm[16], lm[20] || lm[18]),
    neck: calcNeck(lm),
    trunk: calcTrunk(lm),
    hip: getAngle(lm[11], lm[23], lm[25])
  };

  // Determine correctness of each angle
  const correctness = {
    upperArm: posture.upperArm >= 20 && posture.upperArm <= 45,
    forearm: posture.forearm >= 70 && posture.forearm <= 110,
    wrist: posture.wrist >= 85 && posture.wrist <= 95,
    neck: posture.neck >= 20 && posture.neck <= 30,
    trunk: posture.trunk >= 70 && posture.trunk <= 95
  };

  // Draw skeleton with color coding
  drawColorCodedSkeleton(ctx, canvas, lm, correctness);

  // Draw highlighted angles
  drawRULAAngles(ctx, canvas, lm, posture);

  // Process posture assessment
  processRULAPosture(posture, lm, ctx, canvas);
}

// ── Draw Color-Coded Skeleton ───────────────────
function drawColorCodedSkeleton(ctx, canvas, lm, correctness) {
  // Key connections to draw with color coding
  const connections = [
    { start: 11, end: 12, angle: 'general', label: 'Shoulders' },      // shoulder line
    { start: 12, end: 14, angle: 'upperArm', label: 'Upper Arm' },     // upper arm
    { start: 14, end: 16, angle: 'forearm', label: 'Forearm' },        // forearm
    { start: 12, end: 24, angle: 'trunk', label: 'Trunk' },            // trunk
    { start: 24, end: 26, angle: 'general', label: 'Leg' },            // leg
    { start: 0, end: 12, angle: 'neck', label: 'Neck' }                // neck
  ];

  connections.forEach(conn => {
    const p1 = lm[conn.start];
    const p2 = lm[conn.end];
    if (!p1 || !p2) return;

    const isGood = correctness[conn.angle] !== false;
    const color = isGood ? '#10b981' : '#ef4444';

    // Draw line
    ctx.strokeStyle = color;
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(p1.x * canvas.width, p1.y * canvas.height);
    ctx.lineTo(p2.x * canvas.width, p2.y * canvas.height);
    ctx.stroke();

    // Draw joints
    [p1, p2].forEach(p => {
      ctx.fillStyle = color;
      ctx.beginPath();
      ctx.arc(p.x * canvas.width, p.y * canvas.height, 6, 0, 2 * Math.PI);
      ctx.fill();

      ctx.strokeStyle = '#fff';
      ctx.lineWidth = 2;
      ctx.stroke();
    });
  });

  // Draw all other landmarks in neutral gray
  lm.forEach((landmark, idx) => {
    const isKeyJoint = connections.some(c => c.start === idx || c.end === idx);
    if (!isKeyJoint) {
      ctx.fillStyle = 'rgba(100, 100, 100, 0.5)';
      ctx.beginPath();
      ctx.arc(landmark.x * canvas.width, landmark.y * canvas.height, 3, 0, 2 * Math.PI);
      ctx.fill();
    }
  });
}

// ── Process RULA Posture ────────────────────────
function processRULAPosture(posture, lm, ctx, canvas) {
  // Process with RULA assessment
  const result = rulaAssessment.processPosture(posture);
  const feedback = rulaAssessment.getFeedback(posture);

  // Update display
  updateRULADisplay(posture, result, feedback);
}

// ── Update RULA Display ─────────────────────────
function updateRULADisplay(posture, result, feedback) {
  // Update RULA score
  document.getElementById('rula-current-score').textContent = feedback.score;
  
  const qualityBadge = document.getElementById('rula-quality');
  qualityBadge.textContent = feedback.quality.level;
  qualityBadge.className = 'rula-quality-badge ' + feedback.quality.level.toLowerCase();

  // Update timer
  if (result.phase === 'posturing') {
    document.getElementById('rula-posture-timer').innerHTML = 
      `<div class="timer-value">${result.remaining}s</div><div class="timer-label">/ 10s Good Posture</div>`;
    setRULAStatus('good', `Good posture: ${result.remaining}s remaining`);
  } else if (result.phase === 'break') {
    document.getElementById('rula-posture-timer').innerHTML = 
      `<div class="timer-value">${result.remaining}s</div><div class="timer-label">/ 5s Break</div>`;
    setRULAStatus('neutral', `Break: ${result.remaining}s remaining`);
  } else if (result.repComplete) {
    document.getElementById('rula-reps-count').textContent = result.reps;
    setRULAStatus('good', '✓ Rep completed! Break time.');
  } else if (result.phase === 'break-complete') {
    setRULAStatus('neutral', 'Break complete. Ready for next rep.');
  } else if (result.phase === 'failed') {
    setRULAStatus('bad', result.message);
  } else {
    document.getElementById('rula-posture-timer').innerHTML = 
      `<div class="timer-value">0s</div><div class="timer-label">/ 10s Good Posture</div>`;
    setRULAStatus('neutral', feedback.quality.action);
  }

  // Update feedback list
  setRULAFeedback(feedback.feedback);
}

// ── Draw RULA Angles on Canvas ──────────────────
function drawRULAAngles(ctx, canvas, lm, posture) {
  ctx.save();
  
  // Check which angles are in correct range
  const isUpperArmGood = posture.upperArm >= 20 && posture.upperArm <= 45;
  const isForearmGood = posture.forearm >= 70 && posture.forearm <= 110;
  const isWristGood = posture.wrist >= 85 && posture.wrist <= 95;
  const isNeckGood = posture.neck >= 20 && posture.neck <= 30;
  const isTrunkGood = posture.trunk >= 70 && posture.trunk <= 95;

  // Draw angle labels at key joints
  if (lm[14]) {
    drawAngleLabel(ctx, canvas, lm[14], `Arm: ${Math.round(posture.upperArm)}°`, isUpperArmGood ? '#10b981' : '#ef4444');
  }

  if (lm[16]) {
    drawAngleLabel(ctx, canvas, lm[16], `Forearm: ${Math.round(posture.forearm)}°`, isForearmGood ? '#10b981' : '#ef4444');
  }

  if (lm[0]) {
    drawAngleLabel(ctx, canvas, lm[0], `Neck: ${Math.round(posture.neck)}°`, isNeckGood ? '#10b981' : '#ef4444');
  }

  if (lm[24]) {
    drawAngleLabel(ctx, canvas, lm[24], `Trunk: ${Math.round(posture.trunk)}°`, isTrunkGood ? '#10b981' : '#ef4444');
  }

  // Draw overall status bar
  drawRULAStatusBar(ctx, canvas, posture);

  ctx.restore();
}

// ── Helper: Draw Angle Label ────────────────────
function drawAngleLabel(ctx, canvas, joint, label, color) {
  if (!joint || !joint.x || !joint.y) return;
  
  const x = joint.x * canvas.width;
  const y = joint.y * canvas.height;

  ctx.font = 'bold 18px Arial';
  ctx.fillStyle = color;
  ctx.strokeStyle = 'rgba(0,0,0,0.8)';
  ctx.lineWidth = 4;
  
  ctx.strokeText(label, x + 12, y - 12);
  ctx.fillText(label, x + 12, y - 12);
}

// ── Helper: Draw RULA Status Bar ────────────────
function drawRULAStatusBar(ctx, canvas, posture) {
  ctx.save();
  
  const goodCount = 
    (posture.upperArm >= 20 && posture.upperArm <= 45 ? 1 : 0) +
    (posture.forearm >= 70 && posture.forearm <= 110 ? 1 : 0) +
    (posture.wrist >= 85 && posture.wrist <= 95 ? 1 : 0) +
    (posture.neck >= 20 && posture.neck <= 30 ? 1 : 0) +
    (posture.trunk >= 70 && posture.trunk <= 95 ? 1 : 0);
  
  const total = 5;

  // Draw background bar
  ctx.fillStyle = 'rgba(0,0,0,0.7)';
  ctx.fillRect(10, 10, 300, 45);

  // Draw status text
  ctx.font = 'bold 18px Arial';
  ctx.fillStyle = goodCount >= 4 ? '#10b981' : goodCount >= 3 ? '#f59e0b' : '#ef4444';
  ctx.fillText(`${goodCount}/${total} Correct`, 20, 40);

  // Draw percentage bar
  const percentage = Math.round((goodCount / total) * 100);
  const barColor = percentage >= 80 ? '#10b981' : percentage >= 60 ? '#f59e0b' : '#ef4444';
  ctx.fillStyle = barColor;
  ctx.fillRect(180, 25, (120 / 100) * percentage, 12);
  
  ctx.strokeStyle = '#fff';
  ctx.lineWidth = 2;
  ctx.strokeRect(180, 25, 120, 12);

  ctx.restore();
}

// ── RULA UI Helpers ─────────────────────────────
function setRULAStatus(type, msg) {
  const dot = document.getElementById('status-dot-rula');
  dot.className = 'status-dot ' + type;
  document.getElementById('status-text-rula').textContent = msg;
}

function setRULAFeedback(items) {
  const list = document.getElementById('rula-feedback-list');
  list.innerHTML = '';
  items.forEach(f => {
    const icon = f.type === 'good' ? '✅' : f.type === 'warn' ? '⚠️' : 'ℹ️';
    const cls = f.type === 'good' ? 'fb-good' : f.type === 'warn' ? 'fb-warn' : 'fb-neutral';
    list.innerHTML += `<li class="${cls}">${icon} ${f.msg}</li>`;
  });
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

  // Draw skeleton
  drawConnectors(ctx, lm, POSE_CONNECTIONS, {
    color: 'rgba(255, 255, 255, 0.2)',
    lineWidth: 2,
  });
  drawLandmarks(ctx, lm, {
    color: '#10b981',
    fillColor: '#065f46',
    lineWidth: 1,
    radius: 4,
  });

  if (currentEx) processExercise(lm, ctx, canvas);
}

// ── Exercise logic ──────────────────────────────
function processExercise(lm, ctx, canvas) {
  const ex = currentEx;
  
  // RULA Assessment specific logic
  if (ex.id === 'rula_assessment') {
    const rula = calculateRula(lm);
    document.getElementById('rula-score').textContent = rula;
    
    let risk;
    if (rula <= 2)
      risk = 'Acceptable';
    else if (rula <= 4)
      risk = 'Investigate';
    else if (rula <= 6)
      risk = 'Change Soon';
    else
      risk = 'Immediate Action';

    document.getElementById('rula-risk').textContent = risk;

    if (rula >= 5) {
      if (!badPostureStart) {
        badPostureStart = Date.now();
      }

      const seconds = (Date.now() - badPostureStart) / 1000;
      const remaining = Math.max(0, 10 - seconds);

      document.getElementById('rula-timer').textContent = `Alert in ${remaining.toFixed(1)}s`;

      if (seconds >= 10) {
        setStatus('bad', 'Poor posture maintained for 10 seconds');
        setFeedback([{ msg: 'Adjust posture immediately', type: 'warn' }]);
      }
    } else {
      badPostureStart = null;
      document.getElementById('rula-timer').textContent = 'Monitoring...';
    }
  }
  
  // Calculate all angles
  const angles = {};
  ex.angles.forEach(a => {
    const [i1, i2, i3] = a.landmarks;
    angles[a.key] = getAngle(lm[i1], lm[i2], lm[i3]);
  });

  // Update angle bars in UI
  // Update angle bars in UI
  updateAnglesDisplay(angles, ex);

  // Draw angle values on canvas
  drawAngleOverlays(ctx, canvas, lm, angles, ex);

  // Custom rep logic for exercises that define onFrame()
  if (ex.onFrame) {
    const newCount = ex.onFrame(angles);

    if (newCount > repCount) {
      repCount = newCount;
      document.getElementById('rep-count').textContent = repCount;
    }
  }

  // ── Custom exercise rep counting ──
  if (ex.id === 'circumduction') {
    // Track circle completion using arm angle relative to shoulder
    const state = ex._circleState;
    if (!state) {
      ex._circleState = {
        rightPrevAngle: null,
        leftPrevAngle: null,
        rightCrossedZero: false,
        leftCrossedZero: false
      };
    }
    
    // Get current arm angles (direction from shoulder to wrist)
    const rightArmAngle = getArmAngle(lm[12], lm[16]);
    const leftArmAngle = getArmAngle(lm[11], lm[15]);
    
    let repCompleted = false;
    
    // Track right arm circle completion
    if (state.rightPrevAngle !== null) {
      // Detect crossing from high angle to low angle (completing a full circle)
      const rightCrossedZero = (state.rightPrevAngle > 270 && rightArmAngle < 90);
      
      if (rightCrossedZero && !state.rightCrossedZero) {
        state.rightCrossedZero = true;
      }
      
      // If we've crossed zero and now we're back to starting position
      if (state.rightCrossedZero && rightArmAngle < 30 && state.rightPrevAngle < 40) {
        state.rightCrossedZero = false;
        repCompleted = true;
      }
    }
    
    // Track left arm circle completion
    if (state.leftPrevAngle !== null) {
      const leftCrossedZero = (state.leftPrevAngle > 270 && leftArmAngle < 90);
      
      if (leftCrossedZero && !state.leftCrossedZero) {
        state.leftCrossedZero = true;
      }
      
      if (state.leftCrossedZero && leftArmAngle < 30 && state.leftPrevAngle < 40) {
        state.leftCrossedZero = false;
        repCompleted = true;
      }
    }
    
    // Store current angles for next frame
    state.rightPrevAngle = rightArmAngle;
    state.leftPrevAngle = leftArmAngle;
    
    // Count a rep when either arm completes a full circle
    if (repCompleted) {
      repCount++;
      document.getElementById('rep-count').textContent = repCount;
      setPhaseLabel('up');
      
      // Provide feedback
      const circleDirection = state.rightCrossedZero ? "circle completed!" : "circle completed!";
      setFeedback([{ msg: `✓ Full ${circleDirection}`, type: 'good' }]);
    } else {
      setPhaseLabel('down');
    }
    
  } else if (!ex.onFrame) {
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
      }
    } else {
      // Hold exercise
      if (phase === 'start' && repAngle < ex.downAngle) {
        phase = 'hold';
        setPhaseLabel('hold');
      } else if (phase === 'hold' && repAngle > ex.upAngle) {
        phase = 'start';
        setPhaseLabel('start');
      }
    }
  }

  // ── Evaluate coaching rules ──
  const triggered = ex.rules.filter(r => r.check(angles));
  const warnings = triggered.filter(r => r.type === 'warn');
  if (warnings.length > 0) {
    if (!badPostureStart) {
      badPostureStart = Date.now();
    }
    const duration = (Date.now() - badPostureStart) / 1000;
    if (duration >= 10) {
      alertTriggered = true;
    }
  } else {
    badPostureStart = null;
    alertTriggered = false;
  }
  
  if (triggered.length > 0) {
    const first = triggered[0];
    setStatus(first.type === 'good' ? 'good' : 'bad', first.msg);
    setFeedback(triggered.map(r => ({ msg: r.msg, type: r.type })));
  } else if (ex.id !== 'circumduction') {
    const idleMsg = phase === 'down' ? 'Hold position...' : 'Looking good — keep going!';
    setStatus('good', idleMsg);
    setFeedback([{ msg: idleMsg, type: 'good' }]);
  }
  // For circumduction, feedback is already set in the rep counting logic
}

// ── Draw angle text on canvas ───────────────────
function drawAngleOverlays(ctx, canvas, lm, angles, ex) {
  ex.angles.slice(0, 2).forEach(a => {
    const [, i2] = a.landmarks;
    const joint   = lm[i2];
    if (!joint) return;

    const x   = joint.x * canvas.width;
    const y   = joint.y * canvas.height;
    const val = angles[a.key];

    const isInRange = val >= ex.downAngle - 20 && val <= ex.upAngle + 20;
    ctx.save();
    ctx.font         = 'bold 14px Segoe UI, sans-serif';
    ctx.fillStyle    = isInRange ? '#10b981' : '#f87171';
    ctx.strokeStyle  = 'rgba(0,0,0,0.6)';
    ctx.lineWidth    = 3;
    ctx.strokeText(`${val}°`, x + 10, y - 8);
    ctx.fillText(`${val}°`, x + 10, y - 8);
    ctx.restore();
  });
}

// ── UI helpers ──────────────────────────────────
function setStatus(type, msg) {
  const dot  = document.getElementById('status-dot');
  dot.className = 'status-dot ' + type;
  document.getElementById('status-text').textContent = msg;
}

function setPhaseLabel(p) {
  const map = {
    start: ['start', 'Get into position'],
    up:    ['up',    'Great! Keep circling!'],
    down:  ['down',  'Keep circling!'],
    hold:  ['hold',  'Hold the position'],
  };
  const [cls, label] = map[p] || map.start;
  document.getElementById('phase-label').innerHTML =
    `<span class="phase-badge ${cls}">${label}</span>`;
}

function updateAnglesDisplay(angles, ex) {
  const container = document.getElementById('angles-display');
  container.innerHTML = '';

  ex.angles.forEach(a => {
    const val = angles[a.key] || 0;
    const pct = Math.min(100, Math.round((val / 180) * 100));
    
    // Use individual angle's min/max if defined, otherwise use exercise's downAngle/upAngle
    const minVal = a.min !== undefined ? a.min : ex.downAngle;
    const maxVal = a.max !== undefined ? a.max : ex.upAngle;
    const inRange = val >= minVal && val <= maxVal;
    const color   = inRange ? '#10b981' : (val < minVal ? '#3b82f6' : '#f87171');

    container.innerHTML += `
      <div class="angle-row">
        <span class="angle-name">${a.name}</span>
        <span class="angle-val" style="color:${color}">${val}°</span>
      </div>
      <div class="angle-bar-wrap">
        <div class="angle-bar" style="width:${pct}%; background:${color};"></div>
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