#!/bin/bash

# Set Firebase Project ID
FIREBASE_PROJECT_ID="aenzbi-9611331"

# Initialize Firebase project
echo "Initializing Firebase project..."
firebase projects:create --display-name "Hotel-Resto-POS" $FIREBASE_PROJECT_ID
firebase use --add $FIREBASE_PROJECT_ID --alias default

# Initialize Firebase Hosting, Firestore, and Functions
echo "Initializing Firebase Hosting, Firestore, and Functions..."
firebase init hosting firestore functions --project $FIREBASE_PROJECT_ID -y

# Set up Firebase Functions
echo "Setting up Firebase Functions..."
cd functions || exit

# Install required Firebase Functions dependencies
echo "Installing Firebase Functions dependencies..."
npm install firebase-functions firebase-admin

# Create Firebase Functions file if it doesn't exist
FUNCTIONS_FILE="index.js"
echo "Creating Firebase Functions file..."
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

# Go back to root directory
cd ..

# Create Firestore Rules file
RULES_FILE="firestore.rules"
echo "Creating Firestore rules file..."
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

# Set up Firebase Hosting
echo "Setting up Firebase Hosting..."

# Create public directory for hosting
mkdir -p public
echo "Created public directory for Firebase Hosting."

# Create a basic index.html file
cat <<EOF >public/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Hotel Resto POS</title>
</head>
<body>
  <h1>Welcome to Hotel Resto POS</h1>
</body>
</html>
EOF

# Deploy Firestore Rules
echo "Deploying Firestore rules..."
firebase deploy --only firestore:rules

# Deploy Firebase Functions
echo "Deploying Firebase Functions..."
firebase deploy --only functions

# Deploy Firebase Hosting
echo "Deploying Firebase Hosting..."
firebase deploy --only hosting

echo "Firebase project setup complete."