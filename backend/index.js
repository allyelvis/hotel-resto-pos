const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

// Example endpoint: Get all menu items
exports.getMenu = functions.https.onCall(async (data, context) => {
    try {
        const menuSnapshot = await admin.firestore().collection("menu").get();
        const menuItems = menuSnapshot.docs.map(doc => ({id: doc.id, ...doc.data() }));
        return { menuItems };
    } catch (error) {
        console.error("Error getting menu:", error);
        return { error: "Failed to fetch menu items." };
    }
});


// Example endpoint: Add a new menu item (requires authentication)
exports.addMenuItem = functions.https.onCall(async (data, context) => {
    if (!context.auth) {
      return { error: "You must be authenticated to add items." };
    }

    try {
        const newItem = {
            name: data.name,
            price: data.price,
            description: data.description || '', // Optional description
            // ... other properties
        };

        const docRef = await admin.firestore().collection('menu').add(newItem);
        return { message: "Item added successfully", id: docRef.id };
    } catch (error) {
        console.error("Error adding menu item:", error);
        return { error: "Failed to add menu item." };
    }
});

// ... other endpoints for orders, tables, etc.
