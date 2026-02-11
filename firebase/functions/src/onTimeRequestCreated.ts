import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export const onTimeRequestCreated = functions.firestore
  .document("time_requests/{requestId}")
  .onCreate(async (snap) => {
    const data = snap.data();
    const toUserId = data.toUserId as string;
    const fromDisplayName = data.fromDisplayName as string;
    const requestedMinutes = data.requestedMinutes as number;

    // Get recipient's FCM token
    const recipientDoc = await db.collection("users").doc(toUserId).get();
    if (!recipientDoc.exists) return;

    const fcmToken = recipientDoc.data()?.fcmToken;
    if (!fcmToken) return;

    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: "Time Request",
        body: `${fromDisplayName} is requesting ${requestedMinutes} minutes of screen time`,
      },
      data: {
        type: "time_request",
        requestId: snap.id,
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
      console.error("Error sending time request notification:", error);
    }
  });
