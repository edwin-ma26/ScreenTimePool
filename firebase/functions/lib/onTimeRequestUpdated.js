"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.onTimeRequestUpdated = void 0;
const functions = require("firebase-functions");
const admin = require("firebase-admin");
if (!admin.apps.length) {
    admin.initializeApp();
}
const db = admin.firestore();
exports.onTimeRequestUpdated = functions.firestore
    .document("time_requests/{requestId}")
    .onUpdate(async (change) => {
    var _a;
    const before = change.before.data();
    const after = change.after.data();
    // Only process status changes
    if (before.status === after.status)
        return;
    const newStatus = after.status;
    const fromUserId = after.fromUserId;
    const toDisplayName = after.toDisplayName;
    const requestedMinutes = after.requestedMinutes;
    const grantedMinutes = after.grantedMinutes || requestedMinutes;
    const deductsFromGranter = after.deductsFromGranter;
    const toUserId = after.toUserId;
    // Handle deduction from granter's pool if approved/modified
    if ((newStatus === "approved" || newStatus === "modified") &&
        deductsFromGranter) {
        const granterRef = db.collection("users").doc(toUserId);
        try {
            await db.runTransaction(async (transaction) => {
                var _a, _b;
                const granterDoc = await transaction.get(granterRef);
                if (!granterDoc.exists)
                    return;
                const currentPool = (_b = (_a = granterDoc.data()) === null || _a === void 0 ? void 0 : _a.remainingPoolSeconds) !== null && _b !== void 0 ? _b : 0;
                const deductionSeconds = grantedMinutes * 60;
                const newPool = Math.max(0, currentPool - deductionSeconds);
                transaction.update(granterRef, {
                    remainingPoolSeconds: newPool,
                });
            });
        }
        catch (error) {
            console.error("Error deducting from granter pool:", error);
        }
    }
    // Notify the requester about the response
    const requesterDoc = await db.collection("users").doc(fromUserId).get();
    if (!requesterDoc.exists)
        return;
    const fcmToken = (_a = requesterDoc.data()) === null || _a === void 0 ? void 0 : _a.fcmToken;
    if (!fcmToken)
        return;
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
    const message = {
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
    }
    catch (error) {
        console.error("Error sending time request update notification:", error);
    }
});
//# sourceMappingURL=onTimeRequestUpdated.js.map