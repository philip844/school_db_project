Calm Weather Mobile App

This is a comprehensive, standalone mobile weather application built with Flutter (Dart). It provides real-time weather information and forecast data, secured by a custom authentication system that connects to a live backend database. The entire interface utilizes a calm, non-distracting blue/teal color palette.

1. Key Components and Technologies

Component

Technology/Package

Purpose

Framework

Flutter (Dart)

Provides the cross-platform mobile application structure and UI.

Backend/Database

Firebase Core & Firestore

Provides the live cloud database for securely storing user accounts.

Persistence

shared_preferences

Stores the user's login state locally for automatic sign-in on relaunch.

Geolocation

geolocator

Accesses the device's native GPS for automatic location detection.

Network Requests

http

Used for making external API calls (Weather & Geocoding).

Weather Data

Open-Meteo API

Provides current weather conditions and forecast data.

2. Authentication and Security Features

The application requires users to create an account or log in before accessing weather features.

2.1. Account Creation (Sign Up)

The Sign Up process enforces strict security validation before saving credentials to the Firestore database:

Email Validation: The email address must end with @gmail.com.

Password Validation: Passwords must meet four minimum criteria:

Minimum length of 8 characters.

Must contain at least one uppercase letter.

Must contain at least one number.

Must contain at least one special character (symbol).

2.2. User Persistence

Upon successful login or sign up, the application saves a local flag (shared_preferences) and the user's email. This allows the user to relaunch the app and skip the login screen automatically until they explicitly choose to log out.

2.3. Forgot Password Flow

The "Forgot Password?" link triggers a secure, 3-step modal dialog designed to simulate account recovery:

Email Input: Prompts the user for their email address.

Verification Code: Requires the user to enter a mock verification code (123456).

New Password: Allows the user to set a simulated new password.

3. Core Weather Functionality (Visible after Login)

Once authenticated, the user gains access to the full WeatherScreen.

3.1. Data Display

Real-Time Clock: Displays the current time.

Current Conditions: Temperature, wind speed, humidity, and "feels like" temperature.

5-Day Forecast: A scrollable horizontal list showing daily high/low temperatures and conditions.

3.2. User Controls

Icon

Feature

Function

Logout (Red Exit)

Sign Out

Clears the local login state (shared_preferences) and immediately returns the user to the Login screen.

Target (◎)

Geolocation (Auto-Detect)

Uses the device's GPS (geolocator) to find the exact current location and display its weather.

Magnifying Glass (🔍)

City Search (Manual)

Toggles an input bar that allows the user to manually enter any city name and fetch its weather (Forward Geocoding).

Eye Toggle

Password Visibility

Allows the user to show/hide the password text for verification during login/sign up.

4. Installation and Deployment

The application runs independently as a native Android app after compilation.

Android Release Build (Standalone APK)

To generate the final, installable file (.apk) that can be shared and run without the PC connection, run the following command in the project root directory:

flutter build apk --release


The compiled file (app-release.apk) will be found in the build/app/outputs/flutter-apk/ directory.
