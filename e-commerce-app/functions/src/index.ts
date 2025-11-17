import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

/**
 * Cloud Function to send FCM push notifications when a new notification is created
 * Triggers when a document is created in the 'notifications' collection
 */
export const onNotificationCreated = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap: functions.firestore.QueryDocumentSnapshot, context: functions.EventContext) => {
    try {
      const notification = snap.data();
      const notificationId = context.params.notificationId;

      console.log("📨 New notification created:", notificationId);
      console.log("   Type:", notification.type);
      console.log("   Title:", notification.title);
      console.log("   User ID:", notification.userId);

      // Get the user's FCM token
      const userId = notification.userId;
      if (!userId) {
        console.log("⚠️  No userId found in notification");
        return null;
      }

      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (!userDoc.exists) {
        console.log("⚠️  User document not found:", userId);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;

      if (!fcmToken) {
        console.log("⚠️  No FCM token found for user:", userId);
        return null;
      }

      // Prepare the notification message
      const title = notification.title || "New Notification";
      const body = notification.message || notification.body || "";
      const type = notification.type || "general";

      // Build the FCM message
      const message: admin.messaging.Message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          notificationId: notificationId,
          type: type,
          userId: userId,
          orderId: notification.orderId || "",
          productId: notification.productId || "",
          productName: notification.productName || "",
          checkoutId: notification.checkoutId || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "harvest_notifications",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
            defaultLightSettings: true,
            color: "#4CAF50",
            icon: "ic_launcher",
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: title,
                body: body,
              },
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      // Send the message
      const response = await admin.messaging().send(message);
      console.log("✅ Successfully sent notification to user:", userId);
      console.log("   Message ID:", response);

      return response;
    } catch (error) {
      console.error("❌ Error sending notification:", error);
      return null;
    }
  });

/**
 * Cloud Function to send FCM push notifications for cooperative notifications
 * Triggers when a document is created in the 'cooperative_notifications' collection
 */
export const onCooperativeNotificationCreated = functions.firestore
  .document("cooperative_notifications/{notificationId}")
  .onCreate(async (snap: functions.firestore.QueryDocumentSnapshot, context: functions.EventContext) => {
    try {
      const notification = snap.data();
      const notificationId = context.params.notificationId;

      console.log("📨 New cooperative notification created:", notificationId);
      console.log("   Type:", notification.type);
      console.log("   Title:", notification.title);
      console.log("   User ID:", notification.userId);

      // Get the user's FCM token
      const userId = notification.userId;
      if (!userId) {
        console.log("⚠️  No userId found in cooperative notification");
        return null;
      }

      const userDoc = await admin.firestore().collection("users").doc(userId).get();
      if (!userDoc.exists) {
        console.log("⚠️  User document not found:", userId);
        return null;
      }

      const userData = userDoc.data();
      const fcmToken = userData?.fcmToken;

      if (!fcmToken) {
        console.log("⚠️  No FCM token found for user:", userId);
        return null;
      }

      // Prepare the notification message
      const title = notification.title || "New Cooperative Notification";
      const body = notification.message || notification.body || "";
      const type = notification.type || "cooperative";

      // Build the FCM message
      const message: admin.messaging.Message = {
        token: fcmToken,
        notification: {
          title: title,
          body: body,
        },
        data: {
          notificationId: notificationId,
          type: type,
          userId: userId,
          cooperativeId: notification.cooperativeId || "",
          sellerId: notification.sellerId || "",
          sellerName: notification.sellerName || "",
          productId: notification.productId || "",
          productName: notification.productName || "",
          click_action: "FLUTTER_NOTIFICATION_CLICK",
        },
        android: {
          priority: "high",
          notification: {
            channelId: "harvest_notifications",
            priority: "high",
            defaultSound: true,
            defaultVibrateTimings: true,
            defaultLightSettings: true,
            color: "#4CAF50",
            icon: "ic_launcher",
          },
        },
        apns: {
          payload: {
            aps: {
              alert: {
                title: title,
                body: body,
              },
              sound: "default",
              badge: 1,
            },
          },
        },
      };

      // Send the message
      const response = await admin.messaging().send(message);
      console.log("✅ Successfully sent cooperative notification to user:", userId);
      console.log("   Message ID:", response);

      return response;
    } catch (error) {
      console.error("❌ Error sending cooperative notification:", error);
      return null;
    }
  });

/**
 * Cloud Function to send notifications to all buyers when a new product is approved
 * Triggers when a product status changes to 'approved'
 */
export const onProductApproved = functions.firestore
  .document("products/{productId}")
  .onUpdate(async (
    change: functions.Change<functions.firestore.QueryDocumentSnapshot>,
    context: functions.EventContext,
  ) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const productId = context.params.productId;

      // Check if status changed from pending to approved
      if (before.status !== "approved" && after.status === "approved") {
        console.log("📦 Product approved:", productId);
        console.log("   Product name:", after.name);
        console.log("   Seller:", after.sellerName);

        // Get all buyers (users with role 'buyer')
        const buyersSnapshot = await admin
          .firestore()
          .collection("users")
          .where("role", "==", "buyer")
          .get();

        console.log(`   Found ${buyersSnapshot.size} buyers to notify`);

        // Send notification to each buyer who has an FCM token
        const promises: Promise<string>[] = [];

        buyersSnapshot.forEach((buyerDoc: admin.firestore.QueryDocumentSnapshot) => {
          const buyerData = buyerDoc.data();
          const fcmToken = buyerData.fcmToken;

          if (fcmToken) {
            const message: admin.messaging.Message = {
              token: fcmToken,
              notification: {
                title: "🆕 New Product Available!",
                body: `Check out ${after.name} from ${after.sellerName}`,
              },
              data: {
                type: "new_product_buyer",
                productId: productId,
                productName: after.name || "",
                sellerName: after.sellerName || "",
                category: after.category || "",
                price: String(after.price || 0),
                click_action: "FLUTTER_NOTIFICATION_CLICK",
              },
              android: {
                priority: "high",
                notification: {
                  channelId: "harvest_notifications",
                  priority: "default",
                  defaultSound: true,
                  color: "#4CAF50",
                  icon: "ic_launcher",
                },
              },
            };

            promises.push(admin.messaging().send(message));
          }
        });

        await Promise.all(promises);
        console.log(`✅ Sent ${promises.length} notifications to buyers`);
      }

      return null;
    } catch (error) {
      console.error("❌ Error sending product approval notifications:", error);
      return null;
    }
  });

// Note: Order notifications are now handled by onNotificationCreated function
// which triggers when CartService creates a notification in the notifications collection.
// This prevents duplicate notifications.
