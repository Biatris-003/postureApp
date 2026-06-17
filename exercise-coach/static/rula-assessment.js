// ─────────────────────────────────────────────
//  RULA Assessment Tool
//  Comprehensive ergonomic posture evaluation
//  Standard RULA Scoring Methodology
// ─────────────────────────────────────────────

class RULAAssessment {
  constructor() {
    this.reset();
  }

  reset() {
    this.goodPostureStart = null;
    this.breakStart = null;
    this.reps = 0;
    this.phase = 'waiting'; // 'waiting' | 'posturing' | 'breaking'
    this.postureHistory = [];
    this.currentScore = 0;
  }

  // Score upper arm (1-4)
  scoreUpperArm(angle) {
    if (angle >= 20 && angle <= 45) return 1;
    if (angle < 20 || angle > 45 && angle <= 90) return 2;
    return 3;
  }

  // Score forearm (1-2)
  scoreForearm(angle) {
    if (angle >= 70 && angle <= 110) return 1;
    return 2;
  }

  // Score wrist (1-2)
  scoreWrist(angle) {
    if (angle >= 85 && angle <= 95) return 1;
    return 2;
  }

  // Score neck (1-4)
  scoreNeck(angle) {
    if (angle >= 20 && angle <= 30) return 1;
    if (angle > 30 && angle <= 45) return 2;
    return 3;
  }

  // Score trunk (1-4)
  scoreTrunk(angle) {
    if (angle >= 70 && angle <= 95) return 1;
    if (angle > 95 && angle <= 120) return 2;
    return 3;
  }

  // Score legs (1-2)
  scoreLegs(hipAngle) {
    if (hipAngle >= 100 && hipAngle <= 180) return 1;
    return 2;
  }

  // Calculate overall RULA score (1-7)
  calculateRULAScore(posture) {
    const armScore = this.scoreUpperArm(posture.upperArm) + 
                     this.scoreForearm(posture.forearm) +
                     this.scoreWrist(posture.wrist);
    
    const neckScore = this.scoreNeck(posture.neck);
    const trunkScore = this.scoreTrunk(posture.trunk);
    const legScore = this.scoreLegs(posture.hip);

    // Combine scores (simplified RULA methodology)
    let groupAScore = Math.min(10, armScore + neckScore);
    let groupBScore = Math.min(10, trunkScore + legScore);

    // Final RULA score
    const finalScore = Math.min(7, Math.max(1, 
      Math.ceil((groupAScore + groupBScore) / 4)
    ));

    return {
      score: finalScore,
      groupA: groupAScore,
      groupB: groupBScore,
      armScore: armScore,
      neckScore: neckScore,
      trunkScore: trunkScore,
      legScore: legScore
    };
  }

  // Determine posture quality
  getPostureQuality(score) {
    if (score <= 2) return { level: 'EXCELLENT', color: '#10b981', action: 'Maintain this posture' };
    if (score <= 4) return { level: 'GOOD', color: '#3b82f6', action: 'Posture is acceptable' };
    if (score <= 6) return { level: 'FAIR', color: '#f59e0b', action: 'Change posture soon' };
    return { level: 'POOR', color: '#ef4444', action: 'Immediate action needed' };
  }

  // Process posture for rep counting
  processPosture(posture, timestamp = Date.now()) {
    const ruleScore = this.calculateRULAScore(posture);
    this.currentScore = ruleScore.score;
    const quality = this.getPostureQuality(ruleScore.score);

    // Good posture = RULA score <= 2
    const isGoodPosture = ruleScore.score <= 2;

    if (isGoodPosture && this.phase !== 'breaking') {
      // Start or continue good posture timing
      if (!this.goodPostureStart) {
        this.goodPostureStart = timestamp;
        this.phase = 'posturing';
      }

      const duration = (timestamp - this.goodPostureStart) / 1000;

      if (duration >= 10 && this.phase === 'posturing') {
        // Rep completed: 10 seconds of good posture
        this.reps++;
        this.phase = 'breaking';
        this.breakStart = timestamp;
        this.goodPostureStart = null;
        return {
          repComplete: true,
          reps: this.reps,
          phase: 'break',
          message: '✓ Posture rep completed! 5-second break.',
          duration: 10
        };
      }

      if (this.phase === 'posturing') {
        return {
          repComplete: false,
          phase: 'posturing',
          remaining: Math.ceil(10 - duration),
          message: `Good posture: ${Math.floor(duration)}s / 10s`,
          duration: duration
        };
      }
    }

    if (this.phase === 'breaking') {
      const breakDuration = (timestamp - this.breakStart) / 1000;

      if (breakDuration >= 5) {
        // Break complete, reset
        this.phase = 'waiting';
        this.breakStart = null;
        return {
          phase: 'break-complete',
          reps: this.reps,
          message: 'Break complete. Ready for next posture rep.',
          duration: breakDuration
        };
      }

      return {
        phase: 'break',
        remaining: Math.ceil(5 - breakDuration),
        message: `Break: ${Math.floor(breakDuration)}s / 5s`,
        duration: breakDuration
      };
    }

    // Bad posture or reset
    if (!isGoodPosture && this.phase === 'posturing') {
      this.goodPostureStart = null;
      this.phase = 'waiting';
      return {
        phase: 'failed',
        message: `Posture degraded (score: ${ruleScore.score}). Restart.`,
        reps: this.reps
      };
    }

    return {
      phase: 'waiting',
      message: 'Waiting for good posture...',
      reps: this.reps
    };
  }

  // Get detailed feedback
  getFeedback(posture) {
    const rules = this.calculateRULAScore(posture);
    const quality = this.getPostureQuality(rules.score);
    const feedback = [];

    // Upper arm feedback
    if (posture.upperArm < 20 || posture.upperArm > 45) {
      feedback.push({
        type: 'warn',
        msg: `Upper arm angle ${posture.upperArm}° — keep between 20-45°`
      });
    } else {
      feedback.push({
        type: 'good',
        msg: `✓ Upper arm ${posture.upperArm}° (20-45°)`
      });
    }

    // Forearm feedback
    if (posture.forearm < 70 || posture.forearm > 110) {
      feedback.push({
        type: 'warn',
        msg: `Forearm angle ${posture.forearm}° — keep between 70-110°`
      });
    } else {
      feedback.push({
        type: 'good',
        msg: `✓ Forearm ${posture.forearm}° (70-110°)`
      });
    }

    // Wrist feedback
    if (posture.wrist < 85 || posture.wrist > 95) {
      feedback.push({
        type: 'warn',
        msg: `Wrist angle ${posture.wrist}° — keep neutral (85-95°)`
      });
    } else {
      feedback.push({
        type: 'good',
        msg: `✓ Wrist ${posture.wrist}° (neutral)`
      });
    }

    // Neck feedback
    if (posture.neck < 20 || posture.neck > 30) {
      feedback.push({
        type: 'warn',
        msg: `Neck angle ${posture.neck}° — slight forward flexion (20-30°)`
      });
    } else {
      feedback.push({
        type: 'good',
        msg: `✓ Neck ${posture.neck}° (20-30°)`
      });
    }

    // Trunk feedback
    if (posture.trunk < 70 || posture.trunk > 95) {
      feedback.push({
        type: 'warn',
        msg: `Trunk angle ${posture.trunk}° — keep upright (70-95°)`
      });
    } else {
      feedback.push({
        type: 'good',
        msg: `✓ Trunk ${posture.trunk}° (70-95°)`
      });
    }

    return {
      score: rules.score,
      quality: quality,
      feedback: feedback
    };
  }
}

// Global instance
const rulaAssessment = new RULAAssessment();
