#!/bin/bash

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "Firebase CLI not found. Please install it using 'npm install -g firebase-tools'."
    exit 1
fi

# Prompt for Firebase Project ID
read -p "Enter your Firebase Project ID: " FIREBASE_PROJECT_ID

# Create project directory
PROJECT_DIR="hotel_resto_pos"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR" || exit

# Initialize Firebase Project
firebase init hosting firestore functions --project "$FIREBASE_PROJECT_ID" -y

# Set up public directory for Firebase Hosting
echo "Setting up public directory for Firebase Hosting..."
mkdir -p public
cat <<EOF > public/index.html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Hotel Resto POS</title>
</head>
<body>
  <h1>Welcome to Hotel Resto POS</h1>
  <p>This POS system manages restaurant menus, orders, and tables.</p>
</body>
</html>
EOF

# Set up Firestore Security Rules
echo "Creating Firestore security rules..."
cat <<EOF > firestore.rules
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
mkdir -p functions

# Set up Firebase Functions
echo "Setting up Firebase Functions..."
cd functions || exit

# Initialize Firebase Functions and install dependencies
npm init
npm install firebase-functions firebase-admin

# Create Firebase Functions Code
cat <<EOF > index.js
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

# Navigate Back to Project Root Directory
cd ..

# Deploy Firestore Rules, Functions, and Hosting
echo "Deploying Firestore rules, Firebase Functions, and Firebase Hosting..."
firebase deploy --only firestore:rules,functions,hosting

echo "Firebase project setup complete. All directories and files created successfully."cd cd