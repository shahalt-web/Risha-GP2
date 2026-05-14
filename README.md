# Risha App
Application to Build Healthy Habits and Positive Behaviors in Children



## Repository

🔗 GitHub Repository:  
https://github.com/shahalt-web/Risha-GP2



# Overview

Risha is a mobile application designed to help children aged 5 to 12 develop positive daily habits while enabling parents to monitor and guide their behavior.

The system combines habit tracking, motivation (rewards and a virtual character), and parental control features to create an interactive and educational experience.



# Problem Statement

Children today spend significant time on digital devices and often lack motivation to build healthy habits. Existing solutions mainly focus on restriction rather than behavioral improvement.



# Proposed Solution

Risha provides a balanced approach that encourages habit formation through motivation and rewards.

The application uses a single interactive virtual character to engage children while providing parents with tools to monitor their progress and support behavior development.



# Key Features

## Habit Tracking System
- Enables children to track daily habits through a simple and age-appropriate interface.

## Motivation and Rewards
- Provides points and rewards to encourage consistency and engagement.

## Parent Dashboard
- Allows parents to monitor their children’s progress, review activities, and provide effective guidance.


# System Architecture

The system follows a serverless architecture:

- **Frontend:** Flutter (Dart)
- **Backend:** Firebase Firestore
- **Processing and Notifications:** Google Apps Script
- **Reporting and Storage:** Google Sheets



# Technologies Used

- Flutter
- Firebase Firestore
- Google Apps Script
- Google Sheets
- Flutter Testing Framework



# Setup Instructions

## Prerequisites

Before running the project, ensure you have:

- Flutter SDK installed
- Firebase account configured
- Android Studio or VS Code
- Git installed



# Installation

## 1. Clone the Repository

```bash
git clone https://github.com/shahalt-web/Risha-GP2.git
```

## 2. Install Dependencies

```bash
flutter pub get
```

## 3. Set Up Firebase

- Create a Firebase project
- Add an Android application
- Download `google-services.json`
- Place it inside:

```bash
android/app/
```

## 4. Configure Google Apps Script

- Deploy the script as a web application
- Copy the deployment URL
- Update it inside:

```bash
lib/shared/config/apps_script_email_config.dart
```

## 5. Run the Application

```bash
flutter run
```



# System Workflow

1. The user performs an action (e.g., completing a habit)
2. Data is stored in Firebase Firestore
3. Critical operations are stored in a local queue
4. Google Apps Script processes the data
5. Reports and notifications are sent via email



# Testing

All tests were conducted using automated testing tools and frameworks.

## Unit Testing
- Using the Flutter testing framework
- Ensuring correct behavior with valid and invalid inputs

## Integration Testing
- Testing interaction between the application and Firebase
- Testing connectivity with Google Apps Script
- Testing email notification functionality

## System Testing
- Comprehensive testing of authentication, habit tracking, rewards, and notifications

## Acceptance Testing
- Testing with a sample of parents and children
- Focusing on usability and user experience



# Security

- Verification codes are stored as hashed values
- No sensitive data is stored in plain text



# Future Improvements

- AI-powered personalized habit recommendations
- Enhanced parent dashboard



# Limitations

- Some features require an internet connection for synchronization and reporting
- Dependence on Google Apps Script may affect scalability



# Impact

- Encourages children to develop healthy habits
- Improves engagement through gamification
- Provides parents with structured behavioral insights


# Notes

- Update the Google Apps Script URL after each deployment
- Monitor system operations via the Google Sheets queue