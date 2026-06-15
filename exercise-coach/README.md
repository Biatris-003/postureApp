# Exercise Coach 🏋️

Real-time AI exercise coaching using your webcam and MediaPipe Pose.

## Exercises included (✅ from your PDF)

| Exercise | Scenario | Type |
|---|---|---|
| Squat | Scenario 2 — Excessive Slouching | Activation |
| Arm Circumduction | Scenario 1 — Forward Bending | Mobility |
| Lateral Rotation | Scenario 1 — Forward Bending | Mobility |
| Sit-to-Stand | Scenario 6 — Static Posture | Activation |
| Flamingo Stand | Scenario 4 — Left Bending | Balance |
| Side Bending (Right) | Scenario 4 — Left Bending | Mobility |

---

## How to run

### Requirements
- Python 3.7+ (already on most machines)
- A webcam
- Internet connection (MediaPipe loads from CDN on first use)

### Steps

**1. Open a terminal in this folder**

```bash
cd exercise-coach
```

**2. Start the server**

```bash
python server.py
```

The browser will open automatically at `http://localhost:8080`

> ⚠️ You MUST use the server (not just open index.html directly).
> Browsers block webcam access on `file://` URLs for security.

---

## How it works

1. **MediaPipe Pose** detects 33 body landmarks in real-time from your webcam
2. **Angle calculator** measures key joint angles (knee, hip, elbow, etc.)
3. **Rule engine** compares angles to ideal ranges for each exercise
4. **Rep counter** uses a state machine (start → down → up → rep counted)
5. **Coaching feedback** shows green ✅ for correct form, yellow ⚠️ for corrections

---

## Adding more exercises

Open `static/exercises.js` and add a new entry to the `EXERCISES` array.

Each exercise needs:
- `angles[]` — which 3 landmarks define each angle (see landmark indices at top of file)
- `repJoint` — which angle to track for rep counting
- `downAngle` / `upAngle` — thresholds for the down and up positions
- `rules[]` — coaching rules with `check(angles)` function + message

---

## Project structure

```
exercise-coach/
├── index.html          ← Main page (selection + coaching screens)
├── server.py           ← Local HTTP server
├── static/
│   ├── style.css       ← All styling
│   ├── exercises.js    ← Exercise definitions + angle rules
│   └── coach.js        ← MediaPipe pose detection + rep logic
└── README.md
```
