// ─────────────────────────────────────────────
//  MEDIAPIPE LANDMARK INDICES (reference)
//  0  nose          11 left shoulder   12 right shoulder
//  13 left elbow    14 right elbow
//  15 left wrist    16 right wrist
//  23 left hip      24 right hip
//  25 left knee     26 right knee
//  27 left ankle    28 right ankle
// ─────────────────────────────────────────────

const EXERCISES = [
  {
    id: 'squat',
    name: 'Squat',
    scenario: 'Scenario 2 — Excessive Slouching',
    type: 'activation',
    typeLabel: 'Activation',
    cues: 'Feet shoulder-width, chest up, heels on ground',
    angles: [
      { name: 'Left knee',  key: 'leftKnee',  landmarks: [23, 25, 27], min: 75, max: 120 },
      { name: 'Right knee', key: 'rightKnee', landmarks: [24, 26, 28], min: 75, max: 120 },
      { name: 'Left hip',   key: 'leftHip',   landmarks: [11, 23, 25], min: 140, max: 180 },
    ],
    repJoint:   'leftKnee',
    downAngle:  115,   // angle BELOW this = "down" position
    upAngle:    160,   // angle ABOVE this = "up" position
    isHold: false,
    rules: [
      {
        check: (a) => a.leftKnee < 75 || a.rightKnee < 75,
        msg: 'Too deep — stop at ~90°',
        type: 'warn'
      },
      {
        check: (a) => ((a.leftHip || 0) + (a.rightHip || 0)) / 2 < 140,
        msg: 'Keep chest up — avoid leaning forward',
        type: 'warn'
      },
      {
        check: (a) => a.leftKnee >= 80 && a.leftKnee <= 115,
        msg: 'Good squat depth! Push through heels to stand.',
        type: 'good'
      },
    ],
  },

  {
    id: 'circumduction',
    name: 'Arm Circumduction',
    scenario: 'Scenario 1 — Excessive Forward Bending',
    type: 'mobility',
    typeLabel: 'Mobility',
    cues: 'Extend both arms out to the sides (T-shape), trace large circles with both shoulders simultaneously',
    angles: [
      { name: 'Right arm lateral', key: 'rightArm',   landmarks: [11, 12, 14], min: 160, max: 180 },
      { name: 'Left arm lateral',  key: 'leftArm',    landmarks: [12, 11, 13], min: 160, max: 180 },
      { name: 'Right elbow',       key: 'rightElbow', landmarks: [12, 14, 16], min: 150, max: 180 },
      { name: 'Left elbow',        key: 'leftElbow',  landmarks: [11, 13, 15], min: 150, max: 180 },
    ],
    repJoint:   'rightArm',
    downAngle:  160,
    upAngle:    175,
    isHold: false,
    rules: [
      {
        check: (a) => a.rightElbow < 150,
        msg: 'Keep right elbow straight',
        type: 'warn'
      },
      {
        check: (a) => a.leftElbow < 150,
        msg: 'Keep left elbow straight',
        type: 'warn'
      },
      {
        check: (a) => a.rightArm >= 165 && a.rightArm <= 180 && a.leftArm >= 165 && a.leftArm <= 180,
        msg: 'Both arms perfectly horizontal — great T-shape, keep circling!',
        type: 'good'
      },
      {
        check: (a) => a.rightArm < 160,
        msg: 'Right arm not fully out — extend it further to the side',
        type: 'warn'
      },
      {
        check: (a) => a.leftArm < 160,
        msg: 'Left arm not fully out — extend it further to the side',
        type: 'warn'
      },
    ],
  },

  {
    id: 'lateral_rotation',
    name: 'Lateral Rotation',
    scenario: 'Scenario 1 — Excessive Forward Bending',
    type: 'mobility',
    typeLabel: 'Mobility',
    cues: 'Elbow pinned at side at 90°, rotate forearm outward',
    angles: [
      { name: 'Elbow angle',   key: 'elbow',   landmarks: [12, 14, 16], min: 75, max: 115 },
      { name: 'Forearm angle', key: 'forearm',  landmarks: [14, 16, 18], min: 70, max: 140 },
    ],
    repJoint:   'forearm',
    downAngle:  70,
    upAngle:    140,
    isHold: false,
    rules: [
      {
        check: (a) => a.elbow < 75 || a.elbow > 115,
        msg: 'Keep elbow bent at ~90° against your side',
        type: 'warn'
      },
      {
        check: (a) => a.forearm >= 130,
        msg: 'Excellent rotation range!',
        type: 'good'
      },
      {
        check: (a) => a.forearm < 90,
        msg: 'Rotate forearm further outward',
        type: 'warn'
      },
    ],
  },

  {
    id: 'sit_to_stand',
    name: 'Sit-to-Stand',
    scenario: 'Scenario 6 — Static Posture / Micro-break',
    type: 'activation',
    typeLabel: 'Activation',
    cues: 'Lean forward, push through heels to stand fully upright',
    angles: [
      { name: 'Knee angle', key: 'knee',  landmarks: [23, 25, 27], min: 70,  max: 175 },
      { name: 'Hip angle',  key: 'hip',   landmarks: [11, 23, 25], min: 70,  max: 180 },
      { name: 'Trunk lean', key: 'trunk', landmarks: [0, 11, 23],  min: 120, max: 180 },
    ],
    repJoint:      'knee',
    downAngle:     100,   // knee BELOW this = seated / "down" latched
    upAngle:       160,   // knee ABOVE this = standing — rep increments HERE (only if latched)
    isHold:        false,

    // Two-state latch: rep only counts on up-crossing after a confirmed down
    // Usage: call exercise.onFrame(angles) each frame; it returns { repCount, feedback }
    _state: { inDown: false, repCount: 0 },
    onFrame(angles) {
      const k = angles.knee ?? 180;

      // Latch DOWN when seated
      if (!this._state.inDown && k < this.downAngle) {
        this._state.inDown = true;
      }

      // Increment ONLY on up-crossing after a confirmed down
      if (this._state.inDown && k > this.upAngle) {
        this._state.inDown = false;
        this._state.repCount++;
      }

      return this._state.repCount;
    },

    rules: [
      // Phase 1: confirmed seated
      {
        check: (a) => a.knee < 100 && a.hip < 110,
        msg: 'Seated — lean forward then drive through heels to stand',
        type: 'good'
      },
      // Phase 2: mid-transition with good forward lean
      {
        check: (a) => a.trunk >= 130 && a.trunk < 165 && a.knee >= 100 && a.knee <= 140,
        msg: 'Good forward lean — drive through heels now',
        type: 'good'
      },
      // Phase 3: fully upright
      {
        check: (a) => a.knee > 160 && a.hip > 165,
        msg: 'Fully upright — excellent!',
        type: 'good'
      },
      // Warning: trying to stand without leaning first
      {
        check: (a) => a.trunk < 130 && a.knee > 140,
        msg: 'Lean forward before pushing up — shift weight over feet',
        type: 'warn'
      },
      // Warning: hips not opening during rise
      {
        check: (a) => a.knee > 100 && a.knee < 160 && a.hip < 120,
        msg: 'Hips not opening — drive hips forward as you rise',
        type: 'warn'
      },
    ],
  },
  {
    id: 'flamingo',
    name: 'Flamingo Stand',
    scenario: 'Scenario 4 — Left Bending Dominance',
    type: 'balance',
    typeLabel: 'Balance',
    cues: 'Stand on right leg, pull left heel up behind you',
    angles: [
      { name: 'Standing knee', key: 'standKnee',  landmarks: [24, 26, 28], min: 160, max: 180 },
      { name: 'Raised knee',   key: 'raisedKnee', landmarks: [23, 25, 27], min: 60,  max: 100 },
    ],
    repJoint:   'raisedKnee',
    downAngle:  60,
    upAngle:    170,
    isHold: true,
    rules: [
      {
        check: (a) => a.standKnee > 165,
        msg: 'Standing leg is straight — great balance!',
        type: 'good'
      },
      {
        check: (a) => a.standKnee < 140,
        msg: 'Straighten your standing leg',
        type: 'warn'
      },
      {
        check: (a) => a.raisedKnee > 100,
        msg: 'Bend raised knee more — pull heel toward glutes',
        type: 'warn'
      },
    ],
  },
  {
    id: 'side_bend_right',
    name: 'Side bending (right)',
    scenario: 'Scenario 4 — Right Bending Dominance',
    type: 'mobility',
    typeLabel: 'Mobility',  

    cues: 'Reach left arm overhead, slide right hand down your leg, bend torso to the right',

    angles: [
      { name: 'Trunk tilt',   key: 'trunk',    landmarks: [24, 23, 11], min: 85, max: 105 },
      { name: 'Overhead arm', key: 'overhead', landmarks: [23, 11, 13], min: 165, max: 175 },
      { name: 'Reach arm',    key: 'reach',    landmarks: [24, 12, 14], min: 10, max: 20 },
    ],

    repJoint: 'trunk',
    downAngle: 100,
    upAngle: 90,
    isHold: false,

    _state: { inDown: false, repCount: 0 },

    onFrame(angles) {
      const trunk = angles.trunk ?? 0;
      const overhead = angles.overhead ?? 0;
      const reach = angles.reach ?? 180;

      const validForm =
        overhead >= 165 &&
        overhead <= 175 &&
        reach >= 10 &&
        reach <= 20;

      // FIXED: consistent with LEFT side logic
      const isDown = trunk >= 95 && trunk <= 105;
      const isUp   = trunk >= 88 && trunk <= 92;

      // enter bent position
      if (!this._state.inDown && isDown && validForm) {
        this._state.inDown = true;
      }

      // exit + count rep
      if (this._state.inDown && isUp) {
        this._state.inDown = false;
        this._state.repCount++;
      }

      return this._state.repCount;
    },

    rules: [
      {
        check: (a) =>
          (a.trunk ?? 180) >= 85 &&
          (a.trunk ?? 180) <= 105 &&
          (a.overhead ?? 0) >= 165 &&
          (a.overhead ?? 0) <= 175 &&
          (a.reach ?? 180) >= 10 &&
          (a.reach ?? 180) <= 20,
        msg: 'Perfect side-bending posture! Excellent stretch and alignment.',
        type: 'good'
      },

      {
        check: (a) => (a.overhead ?? 0) < 165,
        msg: 'Raise your left arm higher overhead',
        type: 'warn'
      },

      {
        check: (a) => (a.reach ?? 180) > 20,
        msg: 'Slide your right hand further down your leg',
        type: 'warn'
      },

      {
        check: (a) => (a.trunk ?? 180) > 105,
        msg: 'Bend further to the right',
        type: 'warn'
      }
    ]
  },
  {
    id: 'side_bend_left',
    name: 'Side bending (left)',
    scenario: 'Scenario 4 — Left Bending Dominance',
    type: 'mobility',
    typeLabel: 'Mobility',

    cues: 'Reach right arm overhead, slide left hand down your leg, bend torso to the left',

    angles: [
      { name: 'Trunk tilt',   key: 'trunk',    landmarks: [23, 24, 12], min: 85, max: 105 },
      { name: 'Overhead arm', key: 'overhead', landmarks: [24, 12, 14], min: 165, max: 175 },
      { name: 'Reach arm',    key: 'reach',    landmarks: [23, 11, 13], min: 10, max: 20 },
    ],

    repJoint: 'trunk',
    downAngle: 100,
    upAngle: 90,
    isHold: false,

    _state: { inDown: false, repCount: 0 },

    onFrame(angles) {
      const trunk = angles.trunk ?? 0;
      const overhead = angles.overhead ?? 0;
      const reach = angles.reach ?? 180;

      const validForm =
        overhead >= 165 && overhead <= 175 &&
        reach >= 10 && reach <= 20;

      // ONLY FIX: use consistent trunk window
      const isDown = trunk >= 95 && trunk <= 105;
      const isUp   = trunk >= 88 && trunk <= 92;

      if (!this._state.inDown && isDown && validForm) {
        this._state.inDown = true;
      }

      if (this._state.inDown && isUp) {
        this._state.inDown = false;
        this._state.repCount++;
      }

      return this._state.repCount;
    },

    rules: [
      {
        check: (a) =>
          (a.trunk ?? 180) >= 85 &&
          (a.trunk ?? 180) <= 105 &&
          (a.overhead ?? 0) >= 165 &&
          (a.overhead ?? 0) <= 175 &&
          (a.reach ?? 180) >= 10 &&
          (a.reach ?? 180) <= 20,
        msg: 'Perfect side-bending posture! Excellent stretch and alignment.',
        type: 'good'
      },

      {
        check: (a) => (a.overhead ?? 0) < 165,
        msg: 'Raise your right arm higher overhead',
        type: 'warn'
      },

      {
        check: (a) => (a.reach ?? 180) > 20,
        msg: 'Slide your left hand further down your leg',
        type: 'warn'
      }
    ]
  },
  {
    id: 'rula_assessment',
    name: 'RULA Posture Assessment',
    scenario: 'Ergonomic Assessment',
    type: 'assessment',
    typeLabel: 'Assessment',
    cues: 'Sit naturally at a desk or stand in neutral posture',
    angles: [
      { name: 'Upper arm',  key: 'upperArm', landmarks: [12, 14, 16], min: 20, max: 45  }, // shoulder→elbow→wrist
      { name: 'Forearm',    key: 'forearm',  landmarks: [14, 16, 12], min: 70, max: 110 }, // elbow→wrist→shoulder
      { name: 'Wrist flex', key: 'wrist',    landmarks: [16, 12, 14], min: 85, max: 95  }, // wrist angle
      { name: 'Neck',       key: 'neck',     landmarks: [0, 11, 23],  min: 20, max: 30  }, // nose→shoulder→hip
      { name: 'Trunk',      key: 'trunk',    landmarks: [11, 23, 25], min: 70, max: 95  }, // shoulder→hip→knee
    ],
    repJoint:   'upperArm',
    downAngle:  20,
    upAngle:    45,
    isHold: true,
    rules: [
      // Upper arm assessment (correct: 20-45°)
      {
        check: (a) => a.upperArm >= 20 && a.upperArm <= 45,
        msg: '✓ Upper arm angle CORRECT (20-45°) — arm is well-positioned',
        type: 'good'
      },
      {
        check: (a) => a.upperArm < 20,
        msg: '✗ Upper arm angle INCORRECT — too abducted, raise your arm closer to body',
        type: 'warn'
      },
      {
        check: (a) => a.upperArm > 45,
        msg: '✗ Upper arm angle INCORRECT — too elevated, lower your shoulder',
        type: 'warn'
      },

      // Forearm assessment (correct: 70-110°)
      {
        check: (a) => a.forearm >= 70 && a.forearm <= 110,
        msg: '✓ Forearm angle CORRECT (70-110°) — good keyboard/workspace position',
        type: 'good'
      },
      {
        check: (a) => a.forearm < 70,
        msg: '✗ Forearm angle INCORRECT — wrist too flexed, adjust arm position',
        type: 'warn'
      },
      {
        check: (a) => a.forearm > 110,
        msg: '✗ Forearm angle INCORRECT — arm too extended, bring closer to body',
        type: 'warn'
      },

      // Wrist assessment (correct: neutral ~90°)
      {
        check: (a) => a.wrist >= 85 && a.wrist <= 95,
        msg: '✓ Wrist angle CORRECT (neutral) — wrist in good ergonomic position',
        type: 'good'
      },
      {
        check: (a) => a.wrist < 85,
        msg: '✗ Wrist angle INCORRECT — wrist is deviated, maintain neutral position',
        type: 'warn'
      },
      {
        check: (a) => a.wrist > 95,
        msg: '✗ Wrist angle INCORRECT — wrist is deviated, maintain neutral position',
        type: 'warn'
      },

      // Neck assessment (correct: slight flexion ~20-30° forward)
      {
        check: (a) => a.neck >= 20 && a.neck <= 30,
        msg: '✓ Neck angle CORRECT (20-30°) — screen at proper viewing height',
        type: 'good'
      },
      {
        check: (a) => a.neck < 20,
        msg: '✗ Neck angle INCORRECT — neck too straight/extended, raise screen height',
        type: 'warn'
      },
      {
        check: (a) => a.neck > 30,
        msg: '✗ Neck angle INCORRECT — excessive neck flexion, lower screen or move back',
        type: 'warn'
      },

      // Trunk assessment (correct: upright ~70-95° shoulder→hip→knee)
      {
        check: (a) => a.trunk >= 70 && a.trunk <= 95,
        msg: '✓ Trunk angle CORRECT — spine in neutral position, good sitting posture',
        type: 'good'
      },
      {
        check: (a) => a.trunk < 70,
        msg: '✗ Trunk angle INCORRECT — excessive forward bend, sit back in chair',
        type: 'warn'
      },
      {
        check: (a) => a.trunk > 95,
        msg: '✗ Trunk angle INCORRECT — leaning back, maintain upright sitting',
        type: 'warn'
      },
    ],
  },
];