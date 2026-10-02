# Privacy Policy for Smart Roll

**Effective Date:** October 2, 2026  
**Last Updated:** October 2, 2026  
**Developer / Publisher:** Dart Nexus Lab  
**Application Name:** Smart Roll (Package: `com.dartnexuslab.smartroll`)

Dart Nexus Lab ("we", "our", or "us") operates the **Smart Roll** mobile application (the "Service"). This Privacy Policy explains our policies and practices regarding the collection, use, disclosure, and protection of your personal and sensitive data when you use Smart Roll.

By downloading, installing, or using Smart Roll, you agree to the collection and use of information in accordance with this Privacy Policy.

---

## 1. Information We Collect

### A. Personal Information You Provide
When registering for or signing into Smart Roll, we may collect:
* **Full Name**: Used to identify students and faculty members on attendance records.
* **Email Address**: Used for account authentication, password management, and institutional verification.
* **Student Identification / Roll Number**: (Students only) Used to record attendance against institutional academic records.
* **Academic Details**: Department, degree program/course, academic batch, and semester.
* **Faculty Designation**: (Faculty only) Academic rank or title (e.g., Professor, Lecturer).

### B. Device & Hardware Permissions

#### 1. Camera Access (`android.permission.CAMERA`)
* **Purpose**: Used strictly for the real-time optical scanning of dynamic, time-sensitive cryptographic QR codes displayed by course instructors.
* **Data Processing**: QR code image frames are processed in real-time, on-device via Google ML Kit. We **never** record, store, capture, or transmit video recordings or still images to any external server.

#### 2. Precise Location Access (`ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`)
* **Purpose**: Used exclusively to verify that a student is physically present inside the designated classroom or lecture hall during active attendance submission (geofencing validation).
* **Limitations**:
  * Location is accessed **only in the foreground** at the exact moment you scan the lecture QR code.
  * We do **not** collect background location (`ACCESS_BACKGROUND_LOCATION` is explicitly excluded).
  * We do **not** track continuous location or monitor your whereabouts outside active class sessions.
  * Your geographical coordinates are processed alongside a distance verification algorithm (measuring distance between student and instructor) and stored as a tamper-evident audit check with the attendance record.

---

## 2. How We Use Your Information

We use the collected information solely for legitimate educational and attendance management purposes:
* Authenticating user credentials and protecting unauthorized account access.
* Generating and displaying rolling, fraud-resistant QR tokens for faculty sessions.
* Validating physical proximity to classroom venues to eliminate proxy attendance.
* Maintaining accurate, tamper-evident attendance logs for institutional record-keeping.
* Providing students and faculty with attendance summaries, course breakdowns, and analytics.

---

## 3. Cryptographic Security & Anti-Fraud Protection

Smart Roll employs industry-standard cryptographic techniques to prevent attendance fraud:
* **Dynamic Nonce & HMAC Signatures**: Attendance QR tokens refresh periodically with SHA-256 cryptographic signatures.
* **Anti-Replay Validation**: Tokens cannot be re-used, re-scanned, or shared via screenshots.
* **Tamper-Evident Audit Records**: Each confirmed attendance entry generates a cryptographic audit hash bound to the student ID, lecture ID, timestamp, and location.

---

## 4. Third-Party Services & Data Processors

Smart Roll relies on select third-party services that process data in accordance with their respective privacy policies:

* **Google Play Services**: Core Android platform services and security.
* **Firebase Authentication (Google LLC)**: Secure identity management and token issuance. [Google Privacy Policy](https://policies.google.com/privacy)
* **Cloud Firestore (Google LLC)**: Encrypted database storage for academic profiles and attendance entries.
* **Google ML Kit**: On-device barcode/QR code parsing engine.

All network communication is transmitted over secure, encrypted channels (HTTPS / TLS 1.3).

---

## 5. Data Retention & Account Deletion

* **Retention Period**: Academic profile and attendance logs are retained for the duration of the student's or faculty member's institutional enrollment or until account deletion is requested.
* **In-App Self-Service Deletion**: Users can permanently delete their account, credentials, and all recorded attendance history directly from within the app at any time:
  1. Open the **Smart Roll** app and sign into your account.
  2. Tap the top-right menu (`⋮`) or scroll to **Account Settings & Data Deletion**.
  3. Select **Delete Account**.
  4. Confirm your current password to verify account ownership.
  5. Tap **Permanently Delete**. All profile documents in Cloud Firestore, personal attendance logs, and Firebase Authentication credentials are wiped immediately and irreversibly.
* **Email / Web Deletion Request**: Users may also request complete deletion of their account and associated personal data by emailing our support team at [dartnexuslab@gmail.com](mailto:dartnexuslab@gmail.com) with the subject line *"Account Deletion Request"*. Upon verification, all corresponding user records and profile data will be permanently purged within 30 days.

---

## 6. Children's Privacy

Smart Roll is designed for university and college students and academic institutions. Our services are not directed to children under the age of 13. We do not knowingly collect personal identifiable information from children under 13 years of age.

---

## 7. Changes to This Privacy Policy

We may update our Privacy Policy periodically. We will notify users of any material changes by posting the new Privacy Policy on this page and updating the "Last Updated" date at the top of this document.

---

## 8. Contact Us

If you have questions, feedback, or concerns regarding this Privacy Policy or your personal data, please contact:

* **Developer:** Dart Nexus Lab
* **Email:** [dartnexuslab@gmail.com](mailto:dartnexuslab@gmail.com)
* **Repository:** [https://github.com/aliasghar08/qr-attendence-app-in-flutter](https://github.com/aliasghar08/qr-attendence-app-in-flutter)
