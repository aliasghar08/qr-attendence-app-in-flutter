# Smart Roll - Google Play Store Listing & Submission Guide

This document contains all pre-formatted, compliant metadata required to complete your Google Play Store listing and pass Google App Review.

---

## 1. Store Listing Details

* **App Name:** `Smart Roll`
* **Short Description (Max 80 chars):**  
  `Smart geotagged classroom attendance system with fraud-resistant dynamic QR.`
* **Category:** `Education`
* **Tags:** `Education`, `Attendance Tracker`, `QR Code Scanner`, `University`, `Classroom`

### Full Description (Markdown/Text ready for Play Console):
```
Smart Roll is a next-generation academic attendance management system designed for universities, colleges, and educational institutions. Say goodbye to manual roll calls, paper attendance sheets, and proxy attendance fraud.

KEY FEATURES:

🔒 ANTI-FRAUD CRYPTOGRAPHIC QR CODE
Faculty members generate dynamic, rolling QR codes for each lecture session. Protected by SHA-256 cryptographic signatures and anti-replay nonce tracking, tokens update periodically to prevent screenshot sharing or unauthorized reuse.

📍 GEOTAGGED CLASSROOM VERIFICATION
Smart Roll uses real-time foreground location to verify that students are physically present inside the designated classroom or lecture hall during active attendance marking.

⚡ INSTANT REAL-TIME SYNC
Attendance submissions are processed instantaneously with Google Cloud Firestore, giving professors immediate headcounts and attendance rosters.

📊 ATTENDANCE ANALYTICS & MONITORING
Students and faculty can monitor attendance progress with clear subject-by-subject statistics, attendance percentages, and examination eligibility indicators (75% threshold tracking).

👨‍🏫 FACULTY & STUDENT PORTALS
- Faculty: Create lecture sessions, select department/course/batch, project dynamic QR tokens, and inspect detailed student attendance history.
- Students: Quickly scan lecture QR codes, track semester attendance, and review session timestamps.

PRIVACY & SECURITY FIRST:
Camera access is used solely for on-device QR scanning—no video feeds or images are ever stored or uploaded. Location data is accessed strictly in the foreground during attendance verification.

Experience fast, seamless, and tamper-proof classroom attendance with Smart Roll!
```

---

## 2. Mandatory URLs for Play Console

* **Privacy Policy URL:**  
  `https://aliasghar08.github.io/qr-attendence-app-in-flutter/privacy_policy.html`  
  *(Alternative direct markdown URL: `https://raw.githubusercontent.com/aliasghar08/qr-attendence-app-in-flutter/main/PRIVACY_POLICY.md`)*
* **Account Deletion URL / Instructions:**  
  Users can request account deletion by emailing `dartnexuslab@gmail.com` with the subject "Account Deletion Request".

---

## 3. Data Safety Form Answers (Play Console)

When completing the **App content > Data safety** questionnaire in the Play Console:

| Data Type | Collected? | Shared? | Ephemeral / Stored | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Location (Approximate & Precise)** | Yes | No | Stored with attendance log | App functionality, fraud prevention |
| **Personal Info (Name, Email, User IDs)** | Yes | No | Stored (encrypted) | Account management, app functionality |
| **Academic Info (Roll No, Course, Batch)** | Yes | No | Stored (encrypted) | App functionality |
| **Photos and Videos (Camera)** | No | No | On-device only | Camera is used exclusively for live QR scanning; no photos or videos are collected or saved |
| **Device or other IDs** | Yes | No | Stored | Firebase authentication tokens |

* **Security practices:**
  - Data is encrypted in transit (HTTPS/TLS 1.3).
  - You provide a way for users to request that their data be deleted.

---

## 4. App Access / Review Credentials (Crucial for App Review)

Google Play Reviewers require test credentials to log in and review your app. In the Play Console under **App content > App access**, provide:

* **Faculty Test Account:**
  - Email: `faculty.demo@smartroll.edu`
  - Password: `Password@123`
* **Student Test Account:**
  - Email: `student.demo@smartroll.edu`
  - Password: `Password@123`

*(Ensure these two accounts are registered in your Firebase Authentication or create them via the app's sign-up page prior to submitting for production review).*
