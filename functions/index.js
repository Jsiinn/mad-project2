const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

/**
 * AI Overexertion Detection Module
 * Triggered on every new workout document write.
 * Evaluates 3 explainable thresholds and writes aiFlag back to the workout doc.
 */
exports.checkOverexertion = onDocumentCreated(
  "workouts/{workoutId}",
  async (event) => {
    const workoutData = event.data.data();
    const { uid, intensityScore, restGapHours, exerciseType, workoutId } = workoutData;

    const reasons = [];

    // ── Threshold 1: Intensity spike ──────────────────────────────────
    // Flag if today's intensity is >2.5 pts above 7-day rolling average
    const sevenDayAgo = new Date();
    sevenDayAgo.setDate(sevenDayAgo.getDate() - 7);

    const recentSnap = await db
      .collection("workouts")
      .where("uid", "==", uid)
      .where("createdAt", ">=", sevenDayAgo)
      .orderBy("createdAt", "desc")
      .limit(20)
      .get();

    const recentWorkouts = recentSnap.docs
      .filter((d) => d.id !== workoutId)
      .map((d) => d.data());

    if (recentWorkouts.length > 0) {
      const avgIntensity =
        recentWorkouts.reduce((sum, w) => sum + (w.intensityScore || 5), 0) /
        recentWorkouts.length;

      const delta = intensityScore - avgIntensity;
      if (delta > 2.5) {
        reasons.push(
          `Your intensity today (${intensityScore}/10) is ${delta.toFixed(1)} points above your 7-day average (${avgIntensity.toFixed(1)}/10).`
        );
      }
    }

    // ── Threshold 2: Insufficient rest gap ────────────────────────────
    // Strength: <12h rest gap | Cardio: <4h rest gap
    const minRest = exerciseType === "cardio" ? 4 : 12;
    if (restGapHours < minRest) {
      reasons.push(
        `Only ${restGapHours.toFixed(1)} hours since your last workout — ${exerciseType} sessions need at least ${minRest}h of recovery.`
      );
    }

    // ── Threshold 3: Goal mismatch ─────────────────────────────────────
    // Count how many same-type sessions this week vs weekly goal
    const weekAgo = new Date();
    weekAgo.setDate(weekAgo.getDate() - 7);

    const sameTypeSnap = await db
      .collection("workouts")
      .where("uid", "==", uid)
      .where("exerciseType", "==", exerciseType)
      .where("createdAt", ">=", weekAgo)
      .get();

    const userSnap = await db.collection("users").doc(uid).get();
    const weeklyGoal = userSnap.data()?.weeklyGoal || {};
    const goalKey = exerciseType === "cardio" ? "cardioDays" : "strengthDays";
    const weeklyTarget = weeklyGoal[goalKey] || 3;
    const thisWeekCount = sameTypeSnap.docs.filter((d) => d.id !== workoutId).length;

    if (thisWeekCount >= weeklyTarget) {
      reasons.push(
        `You've already completed ${thisWeekCount} ${exerciseType} sessions this week — your goal is ${weeklyTarget}/week.`
      );
    }

    // ── Write aiFlag back to workout document ──────────────────────────
    const triggered = reasons.length > 0;
    const severity = reasons.length >= 2 ? "warning" : "caution";

    await event.data.ref.update({
      aiFlag: {
        triggered,
        reasons,
        severity,
        evaluatedAt: FieldValue.serverTimestamp(),
      },
    });

    // ── Send FCM push if overexertion flagged ──────────────────────────
    if (triggered) {
      const fcmToken = userSnap.data()?.fcmToken;
      if (fcmToken) {
        await getMessaging().send({
          token: fcmToken,
          notification: {
            title: severity === "warning" ? "⚠️ Overexertion Warning" : "💛 Recovery Caution",
            body: reasons[0],
          },
          data: { type: "overexertion", workoutId },
        });
      }
    }

    console.log(`Workout ${workoutId}: aiFlag triggered=${triggered}, reasons=${reasons.length}`);
    return null;
  }
);

/**
 * Challenge Alert: notify all challenge participants when a competitor logs a workout
 */
exports.sendChallengeAlert = onDocumentCreated(
  "workouts/{workoutId}",
  async (event) => {
    const { uid } = event.data.data();

    // Find challenges this user is part of
    const challengeSnap = await db
      .collection("challenges")
      .where("participants", "array-contains", uid)
      .where("status", "==", "open")
      .get();

    const userSnap = await db.collection("users").doc(uid).get();
    const displayName = userSnap.data()?.displayName || "A competitor";

    for (const challengeDoc of challengeSnap.docs) {
      const participants = challengeDoc.data().participants || [];
      const others = participants.filter((p) => p !== uid);

      for (const participantUid of others) {
        const partnerSnap = await db.collection("users").doc(participantUid).get();
        const fcmToken = partnerSnap.data()?.fcmToken;
        if (!fcmToken) continue;

        await getMessaging().send({
          token: fcmToken,
          notification: {
            title: "🔥 Beast Mode Alert",
            body: `${displayName} just logged a workout in "${challengeDoc.data().title}"!`,
          },
          data: {
            type: "challenge_alert",
            challengeId: challengeDoc.id,
          },
        });
      }
    }

    return null;
  }
);
