#!/bin/bash

# Set Firebase Project ID
FIREBASE_PROJECT_ID="aenzbi-9611331"

# Initialize Firebase (if not initialized)
echo "Initializing Firebase..."
if [ ! -d "./firebase.json" ]; then
    firebase init firestore functions hosting --project $FIREBASE_PROJECT_ID
else
    echo "Firebase already initialized."
fi

# Navigate to Firebase Functions directory
cd functions || exit

# Install dependencies
echo "Installing Firebase Functions dependencies..."
npm install firebase-functions firebase-admin

# Create Firebase Functions file if it doesn't exist
FUNCTIONS_FILE="index.js"
if [ ! -f "$FUNCTIONS_FILE" ]; then
    echo "Creating Firebase Functions file: $FUNCTIONS_FILE"
    cat <<EOF >$FUNCTIONS_FILE
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
EOF
else
    echo "Firebase Functions file already exists. Skipping creation."
fi

# Navigate back to the root directory
cd ..

# Create Firestore Rules file if it doesn't exist
RULES_FILE="firestore.rules"
if [ ! -f "$RULES_FILE" ]; then
    echo "Creating Firestore rules file: $RULES_FILE"
    cat <<EOF >$RULES_FILE
service cloud.firestore {
  match /databases/{database}/documents {
    match /menu/{itemId} {
      allow read: if true;
      allow write: if request.auth != null;
    }
    match /orders/{orderId} {
      allow read, write: if request.auth != null;
    }
    match /tables/{tableId} {
      allow read, write: if request.auth != null;
    }
  }
}
EOF
else
    echo "Firestore rules file already exists. Skipping creation."
fi

# Deploy Firestore Rules
echo "Deploying Firestore rules..."
firebase deploy --only firestore:rules

# Deploy Firebase Functions
echo "Deploying Firebase Functions..."
firebase deploy --only functions

# Check for web app directory (assumes web app files in public/)
if [ -d "./public" ]; then
    echo "Deploying Firebase Hosting for web app..."
    firebase deploy --only hosting
else
    echo "No web app directory found. Skipping Firebase Hosting deployment."
fi

echo "Firebas