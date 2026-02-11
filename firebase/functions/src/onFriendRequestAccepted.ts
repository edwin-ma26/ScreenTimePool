import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

export const onFriendRequestAccepted = functions.firestore
  .document("friend_requests/{requestId}")
  .onUpdate(async (change) => {
    const before = change.before.data();
    const after = change.after.data();

    // Only process when status changes to accepted
    if (before.status === after.status || after.status !== "accepted") return;

    const user1Id = after.fromUserId as string;
    const user2Id = after.toUserId as string;
    const user1DisplayName = after.fromDisplayName as string;
    const user2DisplayName = after.toDisplayName as string;

    // Create friendship document with sorted IDs
    const sorted = [user1Id, user2Id].sort();
    const friendshipId = `${sorted[0]}_${sorted[1]}`;

    const friendshipData = {
      userIds: sorted,
      user1Id: sorted[0],
      user2Id: sorted[1],
      user1DisplayName:
        sorted[0] === user1Id ? user1DisplayName : user2DisplayName,
      user2DisplayName:
        sorted[1] === user2Id ? user2DisplayName : user1DisplayName,
      user1DeductsOnGrant: false,
      user2DeductsOnGrant: false,
      status: "active",
    };

    try {
      await db
        .collection("friendships")
        .doc(friendshipId)
        .set(friendshipData);
    } catch (error) {
      console.error("Error creating friendship:", error);
      return;
    }

    // Notify the original sender that their request was accepted
    const senderDoc = await db.collection("users").doc(user1Id).get();
    if (!senderDoc.exists) return;

    const fcmToken = senderDoc.data()?.fcmToken;
    if (!fcmToken) return;

    const message: admin.messaging.Message = {
      token: fcmToken,
      notification: {
        title: "Friend Request Accepted",
        body: `${user2DisplayName} accepted your friend request!`,
      },
      data: {
        type: "friend_request",
        requestId: change.after.id,
        status: "accepted",
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
      console.error("Error sending acceptance notification:", error);
    }
  });
