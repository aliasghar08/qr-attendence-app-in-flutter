# Smart QR Code Attendance System

## 📖 About
This project is a modern, cross-platform Smart Attendance System designed to streamline and secure the attendance tracking process for educational institutions. It utilizes a dual-interface approach: a comprehensive Web Dashboard for teachers to manage sessions and a Mobile Application for students to easily mark their presence. 

By leveraging dynamic, time-sensitive QR codes that refresh automatically, the system effectively eliminates proxy attendance and ensures accurate, real-time record-keeping.

## ✨ Features

### 👨‍🏫 Teacher Portal (Web Interface)
*   **Secure Authentication:** Dedicated login and account creation tailored for faculty and administration.
*   **Teacher Dashboard:** A central hub displaying teaching statistics, including total lectures conducted, total students engaged, and average attendance metrics.
*   **Dynamic QR Code Generation:** Teachers can instantly generate attendance QR codes by selecting specific parameters:
    *   Course (e.g., BSCS, MSCS)
    *   Batch & Semester
    *   Subject
    *   Date & Time Slot
*   **Anti-Proxy Security System:** The generated QR code features an active countdown timer and refreshes automatically every 30 seconds, preventing students from sharing static photos of the code.
*   **Lecture History:** Maintain a detailed log of past lectures, allowing teachers to review how many students attended previous sessions.

### 🎓 Student Portal (Mobile Application)
*   **User Authentication:** Secure mobile login for students.
*   **Integrated QR Scanner:** A fast, built-in camera scanner designed specifically to read the active lecture QR codes from the teacher's screen.
*   **Real-time Validation & Feedback:** 
    *   Immediate "Attendance Marked!" confirmation dialog displaying matched lecture details (Course, Subject, Teacher, Time) and student details.
    *   Robust error handling (e.g., "Invalid QR Code format") for expired or incorrect codes.
*   **Attendance Analytics:** A dedicated "Attendance Records" screen providing:
    *   Subject-wise attendance percentages (e.g., Artificial Intelligence 100%).
    *   A chronological list of all attended lectures with timestamps and statuses.
    *   Detailed view of individual class/lecture IDs.
*   **Student Profile:** Quick access to the student's academic profile, including Roll Number, Department, and Semester.

## 💻 Tech Stack
*   **Frontend (Web & Mobile):** Flutter / Dart
*   **Backend & Database:** Firebase (Authentication, Cloud Firestore for real-time state management and record keeping)
