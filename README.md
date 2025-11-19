Calm Weather Mobile App

This is a modern, cross-platform mobile weather application built with Flutter (Dart). It provides users with current weather conditions, a 5-day forecast, and both automatic location detection (via GPS) and manual city search, all presented using a soothing, calm blue/teal color palette.

1. Key Components and Technologies

Component

Technology/Package

Purpose

Framework

Flutter (Dart)

Provides the mobile application structure and UI rendering.

Geolocation

geolocator

Accesses the device's native GPS to get latitude and longitude.

Network Requests

http

Used for making API calls to external services.

Weather Data

Open-Meteo API

Provides current weather conditions and forecast data.

Location Naming

Nominatim (OpenStreetMap)

Used for Forward Geocoding (converting a city name to coordinates) and Reverse Geocoding (converting coordinates to a city name).

Date/Time Formatting

intl

Handles formatting for the real-time clock and forecast dates.

2. Core Features and Functionality

The app is designed around providing a clear, intuitive user experience focused on essential weather data.

2.1. Dynamic Data Display

Current Conditions: Displays temperature, wind speed, humidity, and "feels like" temperature.

Time & Date: A real-time clock and current date are displayed at the top of the screen.

5-Day Forecast: A horizontally scrollable list at the bottom shows the daily high and low temperatures and general conditions for the next four days.

Thematic Design: The visual theme utilizes a calm, non-distracting gradient of soft blues and teals.

2.2. User Interaction

The primary controls are managed by two Floating Action Buttons (FABs) located in the bottom right corner:

Icon

Feature

Function

Target (◎)

Geolocation (Auto-Detect)

Triggers the device's GPS to find the user's current latitude and longitude, then fetches and displays the weather for that exact location.

Magnifying Glass (🔍)

City Search (Manual)

Toggles an input bar in the header. The user can type any city name, and the app uses Forward Geocoding to locate the city and retrieve its weather data.

2.3. How the App Works (Data Flow)

Start-up: The app runs _handleLocationClick() to attempt automatic detection and display the local weather.

Request Position: The _determinePosition() function uses the geolocator package to get the device's coordinates.

Fetch Data: The coordinates are sent to the Open-Meteo API via the http package, retrieving current weather components and the 5-day forecast.

Name Lookup: The coordinates are also sent to the Nominatim service via _fetchLocationName (Reverse Geocoding) to display a human-readable city or town name.

Display: The UI updates with the location name, current weather, and the list of future forecasts.

3. Installation and Deployment

The application is designed to run independently as a native Android or iOS app.

Android Release Build

To generate the standalone, installable file, run the following command in the project root directory:

flutter build apk --release


The final file, app-release.apk, will be found in the build/app/outputs/flutter-apk/ directory. This file can be shared and installed on any Android device without being connected to the PC.
