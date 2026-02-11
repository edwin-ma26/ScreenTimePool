import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export const onTimeRequestUpdated = functions.firestore
  .document("time_requests/{requestId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only process status changes
    if (before.status === after.status) return;

    const newStatus = after.status as string;
    const fromUserId = after.fromUserId as string;
    const toDisplayName = after.toDisplayName as string;
    const requestedMinutes = after.requestedMinutes as number;
    const grantedMinutes = (after.grantedMinutes as number) || requestedMinutes;
    const deductsFromGranter = after.deductsFromGranter as boolean;
    const toUserId = after.toUserId as string;

    // Handle deduction from granter's pool if approved/modified
    if (
      (newStatus === "approved" || newStatus === "modified") &&
      deductsFromGranter
    ) {
      const granterRef = db.collection("users").doc(toUserId);

      try {
        await db.runTransaction(async (transaction) => {
          const granterDoc = await transaction.get(granterRef);
          if (!granterDoc.exists) return;

          const currentPool = granterDoc.data()?.remainingPoolSeconds ?? 0;
          const deductionSeconds = grantedMinutes * 60;
          const newPool = Math.max(0, currentPool - deductionSeconds);

          transaction.update(granterRef, {
            remainingPoolSeconds: newPool,
          });
        });
      } catch (error) {
        console.error("Error deducting from granter pool:", error);
      }
    }

    // Notify the requester about the response
    const requesterDoc = await db.collection("users").doc(fromUserId).get();
    if (!requesterDoc.exists) return;

    const fcmToken = requesterDoc.data()?.fcmToken;
    if (!fcmToken) return;

    let title = "Time Request Update";
    let body = "";

    switch (newStatus) {
      case "approved":
        body = `${toDisplayName} approved your request for ${requestedMinutes} minutes!`;
        break;
      case "modified":
        body = `${toDisplayName} granted you ${grantedMinutes} minutes (you requested ${requestedMinutes})`;
        break;
      case "denied":
        body = `${toDisplayName} denied your time request`;
        break;
      default:
        return;
    }

    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: { title, body },
      data: {
        type: "time_request",
        requestId: change.after.id,
        status: newStatus,
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      await admin.messaging().send(message);
    } catch (error) {
      console.error("Error sending time request update notification:", error);
    }
  });
