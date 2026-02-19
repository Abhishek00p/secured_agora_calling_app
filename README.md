App Documentation

ipconfig getifaddr en0

App Architecture Overview

Tech Stack

Framework: Flutter (Cross-Platform)

State Management: Riverpod

Architecture Pattern: MVVM

Backend Database: Firebase Firestore

Authentication: Firebase Authentication

Local Storage: Shared Preferences, Secured Storage

Real-Time Communication: Agora SDK

Supported Platforms: Android, iOS, Tablet, macOS, Windows

Application Layers

Presentation Layer (UI)

Screens: Welcome Screen, Login/Register Screen, Home Screen, Join/Create Call Screen, Call Interface.

Widgets: Reusable widgets for buttons, text inputs, dialogs, etc.

State Management: Riverpod for managing states and listeners.

Domain Layer (Logic)

ViewModels (Using Riverpod): Handles business logic for UI.

Use Cases: Isolated business logic functions (e.g., Join Call, Create Call, Send Request, Accept Request).

Data Layer (Repository & Services)

Repositories: Abstract layer for data access.

Data Sources: Firebase Service, Agora Service, Local Storage Service (SharedPreferences, SecuredStorage).

Flow Diagram

User Authentication (Firebase)

Sign Up -> Save user details in Firestore -> Redirect to Home Screen

Login -> Verify credentials via Firebase -> Redirect to Home Screen

Call Flow (Using Agora SDK)

Member creates a call -> Generates Call ID and Password -> Stores in Firestore

User requests to join -> Pop-up for Call ID & Password -> Sends request to Member

Member accepts/rejects -> If accepted, user joins the call

Host can mute/unmute, record, or end the call

Chat and Screen Sharing (Firebase & Agora)

Chat messages stored in Firebase Firestore

Screen sharing handled by Agora SDK

Free Trial Mode -5354-A43B

Allow joining/creating calls with a maximum duration of 5 minutes

Firestore Database Schema

Users Collection

userId (String, Unique)

email (String)

password (Hashed String)

name (String)

contactDetails (Map)

subscriptionDetails (Map)

Calls Collection

callId (String, Unique)

hostId (String)

participants (List of userIds)

startTime (Timestamp)

endTime (Timestamp)

recordingStatus (Boolean)

callPassword (String, Hashed)

Chats Collection

chatId (String, Unique)

callId (String)

messages (Array of Maps)

Call Requests Collection

requestId (String, Unique)

callId (String)

userId (String)

status (String: pending/accepted/rejected)

Incremental Model Breakdown

Phase 1: Authentication System (Firebase)

Implement Login & Register Screens

Integrate Firebase Authentication

Setup Firestore for user data

Phase 2: Basic Call Functionality (Agora SDK)

Implement Home Screen (Join & Create Call)

Setup Agora SDK for voice and video calls

Basic Call Join/Creation flow

Phase 3: Advanced Call Features

Recording (Host only)

Admit/Reject Join Requests

Speaker Focus

Mute/Unmute functionality

Phase 4: Chat & Screen Sharing

Implement Chat feature with Firestore storage

Integrate Screen Sharing with Agora SDK

Phase 5: Free Trial Mode & Final Touches

Implement Free Trial Mode (Max 5 minutes)

Add polish to UI and handle edge cases

Testing & Bug Fixing

Phase 6: Cross-Platform Compatibility

Ensure compatibility across Android, iOS, Tablet, macOS, and Windows

Final Testing & Deployment


--------------------------
# secured_agora_calling_app





delivery  :
Phase 1  ( feedback)
Theme
App flow
Login - register ,
 Name ( fname,lName)
 memberCode
 Password
Email
Meeting working  ( meet joining , mute/unmute)
Free Go through App join or create Call ( max 5 min call )
Drawer : user details  
Phase 2
Admin Section
Add Members
Name, 
Email,
Purchase date
Subscription plan days quarterly
isAcitve
Total user of member
  ● Member List ( user detail , payment status, expiry date) 
● Edit Member Details 
 ● Reminder for Payment Subscription.  button
● Enable/Disable Member button
 Mobile
	Meet : Accept/Reject Request ,45  max limit .
            Phase 1 feedback refactor
            ● Speaker Focus
            ● Host can Mute/Unmute User
            ● Extend Time Feature after scheduled Meeting Hours
Phase 3
   1-1 private room for Host and one user
   ● Cross Platform ( Android,IOS,Macos,windows)
    Recording of Meet ( Host Only option)
    Login/Register Screen with TWO factor Auth using OTP