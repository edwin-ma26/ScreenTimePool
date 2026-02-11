"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onTimeRequestCreated = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
exports.onTimeRequestCreated = functions.firestore
    .document("time_requests/{requestId}")
    .onCreate(async (snap) => {
    var _a;
    const data = snap.data();
    const toUserId = data.toUserId;
    const fromDisplayName = data.fromDisplayName;
    const requestedMinutes = data.requestedMinutes;
    // Get recipient's FCM token
    const recipientDoc = await db.collection("users").doc(toUserId).get();
    if (!recipientDoc.exists)
        return;
    const fcmToken = (_a = recipientDoc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
    if (!fcmToken)
        return;
    const message = {
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
    }
    catch (error) {
        console.error("Error sending time request notification:", error);
    }
});
//# sourceMappingURL=onTimeRequestCreated.js.map