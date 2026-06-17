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
    icon: '🦵',
    scenario: 'Lower body — Activation',
    type: 'activation',
    typeLabel: 'Activation',
    cues: 'Arms forward parallel to floor, sit back until thighs are parallel, then drive up',

    angles: [
      { name: 'Knees', key: 'knees', landmarks: [23, 25, 27], min: 60,  max: 100  },
      { name: 'Hips',  key: 'hips',  landmarks: [11, 23, 25], min: 50,  max: 90 },
      { name: 'Arms',  key: 'arms',  landmarks: [23, 11, 15], min: 100, max: 130 },
    ],

    repJoint:  'knees',
    downAngle: 100,
    upAngle:   160,
    isHold: false,

    _state: {
      inDown:       false,
      repCount:     0,
      downFrames:   0,
      upFrames:     0,
    },
    DOWN_FRAMES_NEEDED: 6,
    UP_FRAMES_NEEDED:   6,

    onFrame(angles) {
      const k = angles.knees ?? 180;
      const h = angles.hips  ?? 180;
      const a = angles.arms  ?? 0;

      // ── Bottom zone ──
      const kneeDown = k >= 60 && k <= 100;
      const hipDown  = h >= 50 && h <= 90;
      const armsUp   = a >= 100 && a <= 130;
      const atBottom = kneeDown && hipDown && armsUp;

      // ── Standing zone ──
      const atTop = k > 160;

      if (!this._state.inDown) {
        if (atBottom) {
          this._state.downFrames++;
        } else {
          this._state.downFrames = 0;
        }
        if (this._state.downFrames >= this.DOWN_FRAMES_NEEDED) {
          this._state.inDown   = true;
          this._state.upFrames = 0;
        }
      } else {
        if (atTop) {
          this._state.upFrames++;
        } else {
          this._state.upFrames = 0;
        }
        if (this._state.upFrames >= this.UP_FRAMES_NEEDED) {
          this._state.inDown     = false;
          this._state.downFrames = 0;
          this._state.upFrames   = 0;
          this._state.repCount++;
        }
      }

      return this._state.repCount;
    },

    rules: [
      {
        check: (a) =>
          (a.knees ?? 0) >= 60  && (a.knees ?? 0) <= 100  &&
          (a.hips  ?? 0) >= 50  && (a.hips  ?? 0) <= 90 &&
          (a.arms  ?? 0) >= 100 && (a.arms  ?? 0) <= 130,
        msg: 'Good depth — knees ~60–90°, hips flexed, arms level. Drive up!',
        type: 'good'
      },
      {
        check: (a) => (a.knees ?? 180) < 60,
        msg: 'Too deep — rise slightly to protect your knees',
        type: 'warn'
      },
      {
        check: (a) => (a.knees ?? 180) > 90 && (a.knees ?? 180) < 160,
        msg: 'Squat deeper — aim for thighs parallel to the floor',
        type: 'warn'
      },
      {
        check: (a) => (a.hips ?? 180) > 110 && (a.knees ?? 180) < 140,
        msg: 'Sit back more — push hips back as you descend',
        type: 'warn'
      },
      {
        check: (a) => (a.hips ?? 180) < 70 && (a.knees ?? 180) < 140,
        msg: 'Excessive forward lean — keep chest up',
        type: 'warn'
      },
      {
        check: (a) => (a.arms ?? 0) < 100 && (a.knees ?? 180) < 150,
        msg: 'Raise arms to shoulder height — parallel to the floor',
        type: 'warn'
      },
    ],
  },
  {
    id: 'sit_to_stand',
    name: 'Sit-to-Stand',
    icon: '🪑',
    scenario: 'Functional — Activation',
    type: 'activation',
    typeLabel: 'Activation',
    cues: 'Lean forward, push through heels to stand fully upright',
    angles: [
      { name: 'Knee angle', key: 'knee',  landmarks: [23, 25, 27], min: 70,  max: 175 },
      { name: 'Hip angle',  key: 'hip',   landmarks: [11, 23, 25], min: 70,  max: 180 },
      { name: 'Trunk lean', key: 'trunk', landmarks: [0, 11, 23],  min: 120, max: 180 },
    ],
    repJoint:      'knee',
    downAngle:     100,
    upAngle:       160,
    isHold:        false,
    _state: { inDown: false, repCount: 0 },
    onFrame(angles) {
      const k = angles.knee ?? 180;
      if (!this._state.inDown && k < this.downAngle) {
        this._state.inDown = true;
      }
      if (this._state.inDown && k > this.upAngle) {
        this._state.inDown = false;
        this._state.repCount++;
      }
      return this._state.repCount;
    },
    rules: [
      {
        check: (a) => a.knee < 100 && a.hip < 110,
        msg: 'Seated — lean forward then drive through heels to stand',
        type: 'good'
      },
      {
        check: (a) => a.trunk >= 130 && a.trunk < 165 && a.knee >= 100 && a.knee <= 140,
        msg: 'Good forward lean — drive through heels now',
        type: 'good'
      },
      {
        check: (a) => a.knee > 160 && a.hip > 165,
        msg: 'Fully upright — excellent!',
        type: 'good'
      },
      {
        check: (a) => a.trunk < 130 && a.knee > 140,
        msg: 'Lean forward before pushing up — shift weight over feet',
        type: 'warn'
      },
      {
        check: (a) => a.knee > 100 && a.knee < 160 && a.hip < 120,
        msg: 'Hips not opening — drive hips forward as you rise',
        type: 'warn'
      },
    ],
  },

  {
    id: 'side_bend_right',
    name: 'Side Bend Right',
    icon: '↪️',
    scenario: 'Lateral — Mobility',
    type: 'mobility',
    typeLabel: 'Mobility',
    cues: 'Left arm overhead by ear, right hand slides down leg — bend to the right',

    // ── Landmark rationale ──────────────────────────────────────────────────
    // Trunk lateral tilt  (RIGHT bend):
    //   getSideBendTrunkAngle() — angle at LEFT shoulder: left-hip → left-shoulder → right-shoulder
    //   [23, 11, 12].  Upright ≈ 90°.  Bending RIGHT opens angle → target 110–120°.
    //   landmarks[] is a dummy [0,0,0]; coach.js intercepts the 'trunk' key and
    //   calls getSideBendTrunkAngle(lm, 'side_bend_right') instead.
    //
    // Overhead arm (LEFT arm raised):
    //   Angle at LEFT shoulder: left-hip → left-shoulder → left-wrist  [23, 11, 15]
    //   Full overhead = 160–170°.
    //
    // Reach arm (RIGHT arm sliding down):
    //   Angle at RIGHT shoulder: right-hip → right-shoulder → right-wrist  [24, 12, 16]
    //   Arm alongside leg pointing toward floor = 16–25°.
    // ───────────────────────────────────────────────────────────────────────
    angles: [
      { name: 'Trunk tilt (lateral)', key: 'trunk',    landmarks: [0, 0, 0],   min: 90, max: 100 },
      { name: 'Overhead arm (L)',     key: 'overhead', landmarks: [23, 11, 15], min: 140, max: 170 },
      { name: 'Reach arm (R)',        key: 'reach',    landmarks: [24, 12, 16], min: 25,  max: 35  },
    ],

    repJoint:  'trunk',
    downAngle: 95,  // trunk ABOVE this = entered bent zone
    upAngle:   95,   // trunk BELOW this = returned upright → rep counted
    isHold: false,

    _state: {
      inDown:     false,
      repCount:   0,
      downFrames: 0,
      upFrames:   0,
    },
    DOWN_FRAMES_NEEDED: 6,
    UP_FRAMES_NEEDED:   6,

    onFrame(angles) {
      const trunk    = angles.trunk    ?? 90;
      const overhead = angles.overhead ?? 0;
      const reach    = angles.reach    ?? 180;

      // All three must be in range simultaneously for a valid bent position
      const trunkOk   = trunk    >= 95 && trunk    <= 105;
      const armOk     = overhead >= 140 && overhead <= 170;
      const reachOk   = reach    >= 25  && reach    <= 35;

      const atBent    = trunkOk && armOk && reachOk;
      const atUpright = trunk <= 95;  // returned to near-vertical

      if (!this._state.inDown) {
        this._state.downFrames = atBent ? this._state.downFrames + 1 : 0;
        if (this._state.downFrames >= this.DOWN_FRAMES_NEEDED) {
          this._state.inDown   = true;
          this._state.upFrames = 0;
        }
      } else {
        this._state.upFrames = atUpright ? this._state.upFrames + 1 : 0;
        if (this._state.upFrames >= this.UP_FRAMES_NEEDED) {
          this._state.inDown     = false;
          this._state.downFrames = 0;
          this._state.upFrames   = 0;
          this._state.repCount++;
        }
      }

      return this._state.repCount;
    },

    rules: [
      {
        check: (a) =>
          (a.trunk    ?? 90)  >= 95 && (a.trunk    ?? 90)  <= 105 &&
          (a.overhead ?? 0)   >= 140 && (a.overhead ?? 0)   <= 170 &&
          (a.reach    ?? 180) >= 25  && (a.reach    ?? 180) <= 35,
        msg: 'Perfect — trunk tilted right, arm overhead, reach arm down. Hold it!',
        type: 'good'
      },
      {
        check: (a) => (a.trunk ?? 90) < 95,
        msg: 'Bend further right — trunk needs to reach 95–105°',
        type: 'warn'
      },
      {
        check: (a) => (a.trunk ?? 90) > 105,
        msg: 'Ease back slightly — past the 95–105° target range',
        type: 'warn'
      },
      {
        check: (a) => (a.overhead ?? 0) < 140,
        msg: 'Raise left arm higher — bicep beside your ear (140–170°)',
        type: 'warn'
      },
      {
        check: (a) => (a.overhead ?? 0) > 170,
        msg: 'Bring left arm in slightly — keep it at 160–170°',
        type: 'warn'
      },
      {
        check: (a) => (a.reach ?? 180) > 25,
        msg: 'Lower right arm — reach down toward the floor (16–25°)',
        type: 'warn'
      },
      {
        check: (a) => (a.reach ?? 180) < 16,
        msg: 'Bring right arm up slightly — target is 16–25°',
        type: 'warn'
      },
    ],
  },

  {
    id: 'side_bend_left',
    name: 'Side Bend Left',
    icon: '↩️',
    scenario: 'Lateral — Mobility',
    type: 'mobility',
    typeLabel: 'Mobility',
    cues: 'Right arm overhead by ear, left hand slides down leg — bend to the left',

    // ── Landmark rationale (exact mirror of side_bend_right) ────────────────
    // Trunk lateral tilt (LEFT bend):
    //   getSideBendTrunkAngle() — same custom fn, passing 'side_bend_left'
    //   so it measures tilt in the opposite direction.
    //   landmarks[] is a dummy [0,0,0]; coach.js intercepts the 'trunk' key.
    //   Upright ≈ 90°. Bending LEFT opens angle → target 115–125°.
    //
    // Overhead arm (RIGHT arm raised):
    //   Angle at RIGHT shoulder: right-hip → right-shoulder → right-wrist [24, 12, 16]
    //   Full overhead = 135–145°.
    //
    // Reach arm (LEFT arm sliding down):
    //   Angle at LEFT shoulder: left-hip → left-shoulder → left-wrist [23, 11, 15]
    //   Arm alongside leg pointing toward floor = 7–14°.
    // ────────────────────────────────────────────────────────────────────────
    angles: [
      { name: 'Trunk tilt (lateral)', key: 'trunk',    landmarks: [0, 0, 0],   min: 115, max: 125 },
      { name: 'Overhead arm (R)',     key: 'overhead', landmarks: [24, 12, 16], min: 135, max: 145 },
      { name: 'Reach arm (L)',        key: 'reach',    landmarks: [23, 11, 15], min: 7,   max: 14  },
    ],

    repJoint:  'trunk',
    downAngle: 115,  // trunk ABOVE this = entered bent zone
    upAngle:   105,  // trunk BELOW this = returned upright → rep counted
    isHold: false,

    _state: {
      inDown:     false,
      repCount:   0,
      downFrames: 0,
      upFrames:   0,
    },
    DOWN_FRAMES_NEEDED: 6,
    UP_FRAMES_NEEDED:   6,

    onFrame(angles) {
      const trunk    = angles.trunk    ?? 90;
      const overhead = angles.overhead ?? 0;
      const reach    = angles.reach    ?? 180;

      // All three must be in range simultaneously for a valid bent position
      const trunkOk  = trunk    >= 115 && trunk    <= 125;
      const armOk    = overhead >= 135 && overhead <= 145;
      const reachOk  = reach    >= 7   && reach    <= 14;

      const atBent    = trunkOk && armOk && reachOk;
      const atUpright = trunk <= 105;  // returned to near-vertical

      if (!this._state.inDown) {
        this._state.downFrames = atBent ? this._state.downFrames + 1 : 0;
        if (this._state.downFrames >= this.DOWN_FRAMES_NEEDED) {
          this._state.inDown   = true;
          this._state.upFrames = 0;
        }
      } else {
        this._state.upFrames = atUpright ? this._state.upFrames + 1 : 0;
        if (this._state.upFrames >= this.UP_FRAMES_NEEDED) {
          this._state.inDown     = false;
          this._state.downFrames = 0;
          this._state.upFrames   = 0;
          this._state.repCount++;
        }
      }

      return this._state.repCount;
    },

    rules: [
      {
        check: (a) =>
          (a.trunk    ?? 90)  >= 115 && (a.trunk    ?? 90)  <= 125 &&
          (a.overhead ?? 0)   >= 135 && (a.overhead ?? 0)   <= 145 &&
          (a.reach    ?? 180) >= 7   && (a.reach    ?? 180) <= 14,
        msg: 'Perfect — trunk tilted left, arm overhead, reach arm down. Hold it!',
        type: 'good'
      },
      {
        check: (a) => (a.trunk ?? 90) < 115,
        msg: 'Bend further left — trunk needs to reach 115–125°',
        type: 'warn'
      },
      {
        check: (a) => (a.trunk ?? 90) > 125,
        msg: 'Ease back slightly — past the 115–125° target range',
        type: 'warn'
      },
      {
        check: (a) => (a.overhead ?? 0) < 135,
        msg: 'Raise right arm higher — bicep beside your ear (135–145°)',
        type: 'warn'
      },
      {
        check: (a) => (a.overhead ?? 0) > 145,
        msg: 'Bring right arm in slightly — keep it at 135–145°',
        type: 'warn'
      },
      {
        check: (a) => (a.reach ?? 180) > 14,
        msg: 'Lower left arm — reach down toward the floor (7–14°)',
        type: 'warn'
      },
      {
        check: (a) => (a.reach ?? 180) < 7,
        msg: 'Bring left arm up slightly — target is 7–14°',
        type: 'warn'
      },
    ],
  },

  {
    id: 'circumduction',
    name: 'Arm Circumduction',
    icon: '🔄',
    scenario: 'Shoulder — Mobility',
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
        msg: 'Both arms perfectly horizontal — gflutter run -d RKGL3019E8Wreat T-shape, keep circling!',
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
];
