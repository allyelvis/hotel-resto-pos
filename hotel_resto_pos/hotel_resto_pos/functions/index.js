const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();
const db = admin.firestore();

// Function: Get Menu Items
exports.getMenu = functions.https.onCall(async (data, context) => {
    try {
        const menuSnapshot = await db.collection("menu").get();
        const menuItems = menuSnapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
        return { menuItems };
    } catch (error) {
        console.error("Error getting menu:", error);
        return { error: "Failed to fetch menu items." };
    }
});

// Function: Add Menu Item
exports.addMenuItem = functions.https.onCall(async (data, context) => {
    if (!context.auth) return { error: "Authentication required." };
    if (!data.name || typeof data.price !== 'number') {
        return { error: "Invalid data for name or price." };
    }
    try {
        const newItem = {
            name: data.name,
            price: data.price,
            description: data.description || '',
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        const docRef = await db.collection("menu").add(newItem);
        return { message: "Item added", id: docRef.id };
    } catch (error) {
        console.error("Error adding menu item:", error);
        return { error: "Failed to add menu item." };
    }
});

// Function: Place an Order
exports.placeOrder = functions.https.onCall(async (data, context) => {
    if (!context.auth) return { error: "Authentication required." };
    try {
        const newOrder = {
            items: data.items,
            tableId: data.tableId || null,
            status: "pending",
            total: data.total,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            userId: context.auth.uid,
        };
        const orderRef = await db.collection("orders").add(newOrder);
        return { message: "Order placed", orderId: orderRef.id };
    } catch (error) {
        console.error("Error placing order:", error);
        return { error: "Failed to place order." };
    }
});

// Function: Update Table Status
exports.updateTableStatus = functions.https.onCall(async (data, context) => {
    if (!context.auth) return { error: "Authentication required." };
    const { tableId, status } = data;
    if (!tableId || !status) return { error: "Table ID and status required." };
    try {
        await db.collection("tables").doc(tableId).update({ status });
        return { message: "Table status updated" };
    } catch (error) {
        console.error("Error updating table status:", error);
        return { error: "Failed to update table status." };
    }
});
