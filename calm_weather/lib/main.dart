import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

void main() {
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mobile Weather App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Set a calm base color
        primarySwatch: Colors.blueGrey,
        fontFamily: 'Inter',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const WeatherScreen(),
    );
  }
}

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  Map<String, dynamic>? _weatherData;
  List<dynamic>? _dailyForecast; // NEW: Store daily forecast data
  String _locationName = "Detecting Location...";
  bool _isLoading = false;
  String? _error;
  DateTime _currentTime = DateTime.now();
  late Timer _timer;

  // New state for search functionality
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  // --- Calm Color Palette ---
  static const Color _calmStartBlue = Color(0xFF88A9C3); // Soft blue/gray
  static const Color _calmEndBlue = Color(0xFFC7D7E3); // Very light, cool blue
  static const Color _calmAccentTeal = Color(
    0xFF5B9B9D,
  ); // Muted Teal/Blue for buttons/icons
  static const Color _calmIconYellow = Color(
    0xFFFFDAA3,
  ); // Soft Pale Gold for sun/brightness
  static const Color _calmDarkBlue = Color(
    0xFF4C7B8F,
  ); // Darker muted blue-green for contrast

  @override
  void initState() {
    super.initState();
    _startClock();
    _handleLocationClick();
  }

  @override
  void dispose() {
    _timer.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Starts the clock timer
  void _startClock() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  // Toggles the search input field visibility
  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _error = null; // Clear error when closing search
      }
    });
  }

  // --- Location and Weather Logic ---

  Future<void> _handleLocationClick() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _locationName = "Locating...";
    });

    try {
      final position = await _determinePosition();
      await _fetchWeather(
        position.latitude,
        position.longitude,
        isGeolocation: true,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
          _locationName = "Location Denied";
        });
      }
    }
  }

  Future<void> _handleCitySearch(String city) async {
    if (city.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _locationName = "Searching for $city...";
    });

    // Forward Geocoding using Nominatim
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(city)}&format=json&limit=1',
        ),
      );

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        if (results.isNotEmpty) {
          final lat = double.parse(results[0]['lat']);
          final lon = double.parse(results[0]['lon']);

          await _fetchWeather(lat, lon);

          // After successful search, close the search bar
          if (mounted) _toggleSearch();
        } else {
          throw 'City not found: $city';
        }
      } else {
        throw 'Failed to connect to search service.';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Search failed: ${e.toString()}';
          _isLoading = false;
          _locationName = "Search Error";
        });
      }
    }
  }

  /// Determines the current position of the device.
  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw 'Location services are disabled.';
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw 'Location permissions are denied.';
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw 'Location permissions are permanently denied. Please enable them in settings.';
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.low,
    );
  }

  /// Fetches a human-readable location name using reverse geocoding.
  Future<void> _fetchLocationName(
    double lat,
    double lon, {
    bool isGeolocation = false,
  }) async {
    // If the location was found via search, we already have a clean city name.
    if (!isGeolocation && _locationName.startsWith('Searching')) {
      return;
    }

    try {
      // Using OpenStreetMap Nominatim for reverse geocoding (free, no key)
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};

        final city =
            address['city'] ??
            address['town'] ??
            address['village'] ??
            address['county'] ??
            "Unknown Location";
        if (mounted) {
          setState(() {
            _locationName = city;
          });
        }
      } else {
        // Fallback to coordinates on API failure
        if (mounted) {
          setState(() {
            _locationName =
                '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationName =
              '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}';
        });
      }
      debugPrint("Failed to get city name: $e");
    }
  }

  /// Fetches weather data from Open-Meteo, including current and daily forecast.
  Future<void> _fetchWeather(
    double lat,
    double lon, {
    bool isGeolocation = false,
  }) async {
    try {
      // UPDATED API CALL: Added 'daily=...' for 5-day forecast
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=5&timezone=auto',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Process daily forecast data
        List<Map<String, dynamic>> dailyData = [];
        final daily = data['daily'];

        if (daily != null) {
          // The API returns arrays for each parameter (time, max temp, min temp, etc.)
          for (int i = 0; i < daily['time'].length; i++) {
            dailyData.add({
              'time': daily['time'][i],
              'weather_code': daily['weather_code'][i],
              'temperature_2m_max': daily['temperature_2m_max'][i].round(),
              'temperature_2m_min': daily['temperature_2m_min'][i].round(),
            });
          }
        }

        if (mounted) {
          setState(() {
            _weatherData = data['current'];
            _dailyForecast = dailyData; // Store the processed daily data
            _isLoading = false;
          });
          _fetchLocationName(
            lat,
            lon,
            isGeolocation: isGeolocation,
          ); // Fetch location name after weather data
        }
      } else {
        throw 'Failed to load weather data with status: ${response.statusCode}';
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to fetch weather data: $e';
          _isLoading = false;
        });
      }
    }
  }

  // --- Utility Functions for UI ---

  // Converts WMO code to an appropriate icon
  IconData _getWeatherIcon(int code, int isDay) {
    bool day = isDay == 1;
    switch (code) {
      case 0:
        return day ? Icons.wb_sunny : Icons.nights_stay;
      case 1:
      case 2:
      case 3:
        return day ? Icons.cloud : Icons.cloud_queue;
      case 45:
      case 48:
        return Icons.cloudy_snowing;
      case 51:
      case 53:
      case 55:
      case 61:
      case 63:
      case 65:
        return Icons.cloudy_snowing;
      case 71:
      case 73:
      case 75:
      case 77:
        return Icons.ac_unit;
      case 80:
      case 81:
      case 82:
        return Icons.beach_access; // Rain showers
      case 95:
      case 96:
      case 99:
        return Icons.thunderstorm;
      default:
        return day ? Icons.wb_sunny : Icons.nights_stay;
    }
  }

  // Converts WMO code to a description string
  String _getWeatherDescription(int code) {
    const Map<int, String> codes = {
      0: "Clear Sky",
      1: "Mainly Clear",
      2: "Partly Cloudy",
      3: "Overcast",
      45: "Foggy",
      48: "Rime Fog",
      51: "Light Drizzle",
      53: "Moderate Drizzle",
      55: "Dense Drizzle",
      61: "Slight Rain",
      63: "Moderate Rain",
      65: "Heavy Rain",
      71: "Slight Snow",
      73: "Moderate Snow",
      75: "Heavy Snow",
      95: "Thunderstorm",
      96: "Thunderstorm & Hail",
    };
    return codes[code] ?? "Unknown";
  }

  // --- UI Builder Methods ---

  @override
  Widget build(BuildContext context) {
    final weather = _weatherData;
    final int temp = weather != null
        ? weather['temperature_2m']?.round() ?? 0
        : 0;
    final int windSpeed = weather != null
        ? weather['wind_speed_10m']?.round() ?? 0
        : 0;
    final int humidity = weather != null
        ? weather['relative_humidity_2m']?.round() ?? 0
        : 0;
    final int feelsLike = weather != null
        ? weather['apparent_temperature']?.round() ?? 0
        : 0;
    final int weatherCode = weather != null ? weather['weather_code'] ?? 0 : 0;
    final int isDay = weather != null ? weather['is_day'] ?? 1 : 1;

    final DateFormat timeFormat = DateFormat('hh:mm a');
    final DateFormat dateFormat = DateFormat('EEE, d MMM');

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient (CALM COLORS)
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_calmStartBlue, _calmEndBlue],
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              // Allow scrolling for the new forecast section
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header (Location & Time) OR Search Bar
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isSearching
                        ? _buildSearchBar()
                        : _buildHeader(timeFormat.format(_currentTime)),
                  ),
                  const SizedBox(height: 16), // Spacing after header
                  // Current Weather Section (Central)
                  SizedBox(
                    height:
                        MediaQuery.of(context).size.height *
                        0.6, // Allocate space for current weather
                    child: Center(
                      child: _buildBody(
                        temp,
                        windSpeed,
                        humidity,
                        feelsLike,
                        weatherCode,
                        isDay,
                        dateFormat.format(_currentTime),
                      ),
                    ),
                  ),

                  // Daily Forecast Section (NEW)
                  if (_dailyForecast != null && _weatherData != null)
                    _buildDailyForecast(),
                ],
              ),
            ),
          ),
        ],
      ),
      // Floating Action Buttons for Location and Search
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search Button (New)
          FloatingActionButton(
            onPressed: _toggleSearch,
            heroTag: 'searchBtn',
            backgroundColor: _isSearching ? Colors.redAccent : _calmAccentTeal,
            elevation: 8,
            shape: const CircleBorder(),
            child: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          // Location Button (Existing)
          FloatingActionButton(
            onPressed: _isLoading ? null : _handleLocationClick,
            heroTag: 'locationBtn',
            backgroundColor: _calmAccentTeal,
            elevation: 8,
            shape: const CircleBorder(),
            child: _isLoading && !_isSearching
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.my_location, color: Colors.white, size: 24),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildHeader(String timeString) {
    return Row(
      key: const ValueKey('header'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Location Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                _locationName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        // Time Display
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              timeString,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      key: const ValueKey('search'),
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        autofocus: true,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) => _handleCitySearch(value),
        style: TextStyle(color: _calmDarkBlue),
        decoration: InputDecoration(
          hintText: 'Search city...',
          hintStyle: TextStyle(color: _calmDarkBlue.withValues(alpha: 0.6)),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: _calmDarkBlue),
          suffixIcon: IconButton(
            icon: Icon(
              Icons.clear,
              color: _calmDarkBlue.withValues(alpha: 0.6),
            ),
            onPressed: () {
              _searchController.clear();
            },
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildBody(
    int temp,
    int windSpeed,
    int humidity,
    int feelsLike,
    int weatherCode,
    int isDay,
    String dateString,
  ) {
    if (_error != null) {
      return _buildErrorWidget();
    }

    if (_isLoading || _weatherData == null) {
      return _buildLoadingWidget();
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Date Chip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(
              alpha: 0.1,
            ), // Darker background for light theme
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Text(
            dateString,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 32),

        // Main Icon (CALM ICON YELLOW)
        Icon(
          _getWeatherIcon(weatherCode, isDay),
          color: _calmIconYellow,
          size: 100,
        ),
        const SizedBox(height: 24),

        // Temperature
        Text(
          '$temp°',
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..shader = const LinearGradient(
                colors: <Color>[
                  Colors.white,
                  Color(0xFFF0F4F7),
                ], // Lighter gradient for softer background
              ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
          ),
        ),
        const SizedBox(height: 8),

        // Description
        Text(
          _getWeatherDescription(weatherCode),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),

        // Feels Like
        Text(
          'Feels like $feelsLike°',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 40),

        // Grid Stats
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStatCard(
              icon: Icons.air,
              iconColor: _calmAccentTeal, // New calm accent
              label: 'Wind',
              value: '$windSpeed km/h',
            ),
            const SizedBox(width: 20),
            _buildStatCard(
              icon: Icons.opacity,
              iconColor: _calmDarkBlue, // Darker calm blue
              label: 'Humidity',
              value: '$humidity%',
            ),
          ],
        ),
        // Spacer to push current weather section up slightly
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildLoadingWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 50,
          height: 50,
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              _calmAccentTeal,
            ), // New calm accent
            strokeWidth: 4.0,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _locationName,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _handleLocationClick,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _calmDarkBlue, // Used a dark calm color for the button
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Retry Location',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.1), // Soft dark overlay
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(icon, size: 24, color: iconColor),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- NEW: Daily Forecast Widget ---
  Widget _buildDailyForecast() {
    if (_dailyForecast == null || _dailyForecast!.isEmpty) {
      return const SizedBox.shrink();
    }

    // Skip the first day since it's the current day (covered by the main screen)
    final forecastList = _dailyForecast!.skip(1).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8.0, bottom: 8.0),
          child: Text(
            '5-Day Forecast',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // ListView.builder embedded in a fixed height container
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: forecastList.length,
            itemBuilder: (context, index) {
              final day = forecastList[index];
              final DateTime date = DateTime.parse(day['time']);
              final String dayOfWeek = DateFormat('EEE').format(date);
              final int maxTemp = day['temperature_2m_max'];
              final int minTemp = day['temperature_2m_min'];
              final int weatherCode = day['weather_code'];

              return Padding(
                padding: const EdgeInsets.only(right: 12.0),
                child: Container(
                  width: 90,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        dayOfWeek,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        _getWeatherIcon(
                          weatherCode,
                          1,
                        ), // Assume daytime icon for forecast summary
                        color: _calmIconYellow.withValues(alpha: 0.8),
                        size: 32,
                      ),
                      Text(
                        '$maxTemp° / $minTemp°',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
