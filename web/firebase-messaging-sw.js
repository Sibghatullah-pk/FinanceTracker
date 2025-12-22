// web/firebase-messaging-sw.js

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize Firebase
firebase.initializeApp({
  apiKey: "AIzaSyDuCOoUU9tjt7qEpk6Oxw62XB9EQKwMbVI",
  authDomain: "finance-tracker-app-86606.firebaseapp.com",
  projectId: "finance-tracker-app-86606",
  storageBucket: "finance-tracker-app-86606.firebasestorage.app",
  messagingSenderId: "201343830980",
  appId: "1:201343830980:web:8b9cfe3ab0d0a18b7e7291"
});

// Retrieve messaging instance
const messaging = firebase.messaging();

// Optional: Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message:', payload);
  const notificationTitle = payload.notification?.title || 'Notification';
  const notificationOptions = {
    body: payload.notification?.body || '',
    icon: '/icons/icon-192.png' // optional icon path
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
