import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export const onFriendRequestCreated = functions.firestore
  .document("friend_requests/{requestId}")
  .onCreate(async (snap) => {
    const data = snap.data();
    const toUserId = data.toUserId as string;
    const fromDisplayName = data.fromDisplayName as string;

    // Get target user's FCM token
    const targetDoc = await db.collection("users").doc(toUserId).get();
    if (!targetDoc.exists) return;

    const fcmToken = targetDoc.data()?.fcmToken;
    if (!fcmToken) return;

    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: "Friend Request",
        body: `${fromDisplayName} wants to be your friend`,
      },
      data: {
        type: "friend_request",
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
      console.error("Error sending friend request notification:", error);
    }
  });
