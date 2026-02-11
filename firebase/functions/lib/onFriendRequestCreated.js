"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onFriendRequestCreated = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
exports.onFriendRequestCreated = functions.firestore
    .document("friend_requests/{requestId}")
    .onCreate(async (snap) => {
    var _a;
    const data = snap.data();
    const toUserId = data.toUserId;
    const fromDisplayName = data.fromDisplayName;
    // Get target user's FCM token
    const targetDoc = await db.collection("users").doc(toUserId).get();
    if (!targetDoc.exists)
        return;
    const fcmToken = (_a = targetDoc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
    if (!fcmToken)
        return;
    const message = {
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
    }
    catch (error) {
        console.error("Error sending friend request notification:", error);
    }
});
//# sourceMappingURL=onFriendRequestCreated.js.map