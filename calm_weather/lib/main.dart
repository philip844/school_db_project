import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import 'package:intl/intl.dart'; 

// ------------------------------------
// NEW: Mock Authentication Service
// ------------------------------------
class AuthService {
  final StreamController<bool> _authStateController = StreamController<bool>.broadcast();
  Stream<bool> get authStateChanges => _authStateController.stream;

  AuthService() {
    // We already added the initial state in the constructor
    _authStateController.add(false); 
  }

  Future<void> signIn(String email, String password) async {
    await Future.delayed(const Duration(seconds: 1));
    
    if (email.isNotEmpty && password.isNotEmpty) {
      _authStateController.add(true);
    } else {
      throw 'Invalid credentials. Please use mock data.';
    }
  }

  void signOut() {
    _authStateController.add(false);
  }

  void dispose() {
    _authStateController.close();
  }
}
// ------------------------------------

final AuthService _authService = AuthService();

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
        primarySwatch: Colors.blueGrey,
        fontFamily: 'Inter',
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: StreamBuilder<bool>(
        // FIX: Added initialData to prevent the app from getting stuck in the 'waiting' state
        initialData: false, 
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          // If we have data, show the appropriate screen immediately
          if (snapshot.hasData) {
            final isLoggedIn = snapshot.data!;
            if (isLoggedIn) {
              return const WeatherScreen();
            } else {
              return const AuthScreen(); 
            }
          }
          // Fallback loader if there's no data (should not happen with initialData set)
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
            backgroundColor: Color(0xFF88A9C3),
          );
        },
      ),
    );
  }
}

// ------------------------------------
// UPDATED: Authentication Screen (Refined UI and Added Forgot Password Flow)
// ------------------------------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  // Controllers for the Forgot Password flow
  final TextEditingController _resetEmailController = TextEditingController();
  final TextEditingController _resetCodeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  
  // --- Calm Color Palette ---
  static const Color _calmStartBlue = Color(0xFF88A9C3); 
  static const Color _calmEndBlue = Color(0xFFC7D7E3); 
  static const Color _calmAccentTeal = Color(0xFF5B9B9D); 
  static const Color _calmDarkBlue = Color(0xFF4C7B8F); 
  static const Color _calmPrimaryTextColor = Color(0xFF333D47); 

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _resetEmailController.dispose();
    _resetCodeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // NOTE: This is a mock login. Any non-empty email/password will work.
      await _authService.signIn(_emailController.text.trim(), _passwordController.text.trim());
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _forgotPasswordFlow() async {
    String message = '';
    
    // Step 1: Request Email and Send Code
    await showDialog(
      context: context,
      builder: (context) => _buildResetDialog(
        context,
        title: 'Reset Password (Step 1 of 3)',
        controller: _resetEmailController,
        labelText: 'Email Address',
        hintText: 'Enter your email for the code',
        keyboardType: TextInputType.emailAddress,
        nextButtonText: 'Send Code',
        onNext: () async {
          if (_resetEmailController.text.isEmpty) {
            message = 'Please enter an email.';
            return false;
          }
          await Future.delayed(const Duration(seconds: 1));
          message = 'Verification code simulated and sent!';
          return true;
        },
      ),
    );

    if (!message.contains('sent')) return;
    
    // Step 2: Verify Code
    await showDialog(
      context: context,
      builder: (context) => _buildResetDialog(
        context,
        title: 'Reset Password (Step 2 of 3)',
        controller: _resetCodeController,
        labelText: 'Verification Code',
        hintText: 'Enter the 6-digit code',
        keyboardType: TextInputType.number,
        nextButtonText: 'Verify Code',
        onNext: () async {
          if (_resetCodeController.text != '123456') { // Mock code: 123456
            message = 'Invalid code. Try 123456.';
            return false;
          }
          await Future.delayed(const Duration(seconds: 1));
          message = 'Code verified!';
          return true;
        },
      ),
    );

    if (!message.contains('verified')) return;

    // Step 3: Set New Password
    await showDialog(
      context: context,
      builder: (context) => _buildResetDialog(
        context,
        title: 'Reset Password (Step 3 of 3)',
        controller: _newPasswordController,
        labelText: 'New Password',
        hintText: 'Enter your new password',
        obscureText: true,
        keyboardType: TextInputType.visiblePassword,
        nextButtonText: 'Reset Password',
        onNext: () async {
          if (_newPasswordController.text.length < 6) {
            message = 'Password must be at least 6 characters.';
            return false;
          }
          await Future.delayed(const Duration(seconds: 1));
          message = 'Password successfully reset!';
          return true;
        },
      ),
    );
    
    // Final confirmation message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
    
    // Clear mock controllers
    _resetEmailController.clear();
    _resetCodeController.clear();
    _newPasswordController.clear();
  }

  // Helper widget for the multi-step modal dialog
  Widget _buildResetDialog(
    BuildContext context, {
    required String title,
    required TextEditingController controller,
    required String labelText,
    required String hintText,
    required String nextButtonText,
    required Future<bool> Function() onNext,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
  }) {
    String currentError = '';
    bool isProcessing = false;

    return StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          backgroundColor: _calmEndBlue.withOpacity(0.95), // Light, calm background
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(title, style: TextStyle(color: _calmDarkBlue, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                keyboardType: keyboardType,
                obscureText: obscureText,
                decoration: _buildInputDecoration(labelText, Icons.vpn_key),
                style: TextStyle(color: _calmPrimaryTextColor),
              ),
              if (currentError.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Text(
                    currentError,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: _calmDarkBlue)),
            ),
            ElevatedButton(
              onPressed: isProcessing ? null : () async {
                setState(() => isProcessing = true);
                currentError = '';
                if (await onNext()) {
                  if (mounted) Navigator.of(context).pop();
                } else {
                  // Error message is set inside the onNext function, retrieve and display it
                  currentError = (await Future.value(null)); 
                  // Placeholder: Since onNext doesn't return the error, we use the message set in the main function.
                  // For a real app, the error message would be returned/passed back here.
                }
                setState(() => isProcessing = false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _calmAccentTeal,
              ),
              child: isProcessing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(nextButtonText, style: const TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_calmStartBlue, _calmEndBlue], 
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                const Center(
                  child: Text(
                    'Welcome Back',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 60),
                
                // Email Field (Full Width, Clean Look)
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: _calmPrimaryTextColor),
                  decoration: _buildInputDecoration(
                    'Email', 
                    Icons.email_outlined, 
                  ),
                ),
                const SizedBox(height: 20),

                // Password Field (Full Width, Clean Look)
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  style: TextStyle(color: _calmPrimaryTextColor),
                  decoration: _buildInputDecoration(
                    'Password', 
                    Icons.lock_outline, 
                  ),
                ),
                const SizedBox(height: 10),

                // Forgot Password Link (UPDATED ACTION)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPasswordFlow,
                    child: Text(
                      'Forgot Password?',
                      style: TextStyle(color: _calmDarkBlue, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // Error Display
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20.0),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                  ),

                // Login Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _calmAccentTeal, // Calm accent color
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        )
                      : const Text(
                          'LOGIN',
                          style: TextStyle(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.white
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Helper for consistent input styling (Mimics the clean, full-width look)
  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: _calmPrimaryTextColor.withOpacity(0.7)),
      filled: true,
      fillColor: Colors.white.withOpacity(0.85), // Soft white fill
      prefixIcon: Icon(icon, color: _calmDarkBlue),
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 15),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.2), width: 1), 
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.4), width: 1), // Soft white outline
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _calmAccentTeal, width: 2), // Teal border when focused
      ),
    );
  }
}
// ------------------------------------
// END UPDATED: Authentication Screen
// ------------------------------------


// ------------------------------------
// START: Weather Screen (No changes needed)
// ------------------------------------

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
  static const Color _calmEndBlue = Color(0xFFC7D7E3);   // Very light, cool blue
  static const Color _calmAccentTeal = Color(0xFF5B9B9D); // Muted Teal/Blue for buttons/icons
  static const Color _calmIconYellow = Color(0xFFFFDAA3); // Soft Pale Gold for sun/brightness
  static const Color _calmDarkBlue = Color(0xFF4C7B8F); // Darker muted blue-green for contrast

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
      await _fetchWeather(position.latitude, position.longitude, isGeolocation: true);
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
      final response = await http.get(Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(city)}}&format=json&limit=1'
      ));

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

    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.low);
  }

  /// Fetches a human-readable location name using reverse geocoding.
  Future<void> _fetchLocationName(double lat, double lon, {bool isGeolocation = false}) async {
    // If the location was found via search, we already have a clean city name.
    if (!isGeolocation && _locationName.startsWith('Searching')) {
      return; 
    }

    try {
      // Using OpenStreetMap Nominatim for reverse geocoding (free, no key)
      final response = await http.get(Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon'));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final address = data['address'] ?? {};
        
        final city = address['city'] ?? address['town'] ?? address['village'] ?? address['county'] ?? "Unknown Location";
        if (mounted) {
          setState(() {
            _locationName = city;
          });
        }
      } else {
        // Fallback to coordinates on API failure
        if (mounted) {
          setState(() {
            _locationName = '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationName = '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}';
        });
      }
      print("Failed to get city name: $e");
    }
  }

  /// Fetches weather data from Open-Meteo, including current and daily forecast.
  Future<void> _fetchWeather(double lat, double lon, {bool isGeolocation = false}) async {
    try {
      // UPDATED API CALL: Added 'daily=...' for 5-day forecast
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,wind_speed_10m&daily=weather_code,temperature_2m_max,temperature_2m_min&forecast_days=5&timezone=auto'
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
          _fetchLocationName(lat, lon, isGeolocation: isGeolocation); // Fetch location name after weather data
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
      0: "Clear Sky", 1: "Mainly Clear", 2: "Partly Cloudy", 3: "Overcast",
      45: "Foggy", 48: "Rime Fog", 51: "Light Drizzle", 53: "Moderate Drizzle", 
      55: "Dense Drizzle", 61: "Slight Rain", 63: "Moderate Rain", 65: "Heavy Rain",
      71: "Slight Snow", 73: "Moderate Snow", 75: "Heavy Snow", 95: "Thunderstorm", 
      96: "Thunderstorm & Hail"
    };
    return codes[code] ?? "Unknown";
  }

  // --- UI Builder Methods ---

  @override
  Widget build(BuildContext context) {
    final weather = _weatherData;
    final int temp = weather != null ? weather['temperature_2m']?.round() ?? 0 : 0;
    final int windSpeed = weather != null ? weather['wind_speed_10m']?.round() ?? 0 : 0;
    final int humidity = weather != null ? weather['relative_humidity_2m']?.round() ?? 0 : 0;
    final int feelsLike = weather != null ? weather['apparent_temperature']?.round() ?? 0 : 0;
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
            child: SingleChildScrollView( // Allow scrolling for the new forecast section
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
                    height: MediaQuery.of(context).size.height * 0.6, // Allocate space for current weather
                    child: Center(
                      child: _buildBody(
                        temp, windSpeed, humidity, feelsLike, weatherCode, isDay, dateFormat.format(_currentTime)
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
          // Logout Button (NEW: Added to Weather Screen)
          FloatingActionButton(
            onPressed: () {
              // Sign out the user
              _authService.signOut();
            },
            heroTag: 'logoutBtn',
            backgroundColor: Colors.redAccent,
            elevation: 8,
            shape: const CircleBorder(),
            child: const Icon(Icons.logout, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 16),

          // Search Button 
          FloatingActionButton(
            onPressed: _toggleSearch,
            heroTag: 'searchBtn',
            backgroundColor: _isSearching ? Colors.redAccent : _calmAccentTeal, 
            elevation: 8,
            shape: const CircleBorder(),
            child: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white, size: 24),
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
                    color: Colors.white
                  )
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
            color: Colors.black.withOpacity(0.1),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_on, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                _locationName,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
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
              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
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
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
          hintStyle: TextStyle(color: _calmDarkBlue.withOpacity(0.6)),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: _calmDarkBlue),
          suffixIcon: IconButton(
            icon: Icon(Icons.clear, color: _calmDarkBlue.withOpacity(0.6)),
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
    String dateString
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
            color: Colors.black.withOpacity(0.1), // Darker background for light theme
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            dateString,
            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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
                colors: <Color>[Colors.white, Color(0xFFF0F4F7)], // Lighter gradient for softer background
              ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
          ),
        ),
        const SizedBox(height: 8),
        
        // Description
        Text(
          _getWeatherDescription(weatherCode),
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w500),
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
            valueColor: AlwaysStoppedAnimation<Color>(_calmAccentTeal), // New calm accent
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
        color: Colors.red.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
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
              backgroundColor: _calmDarkBlue, // Used a dark calm color for the button
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Retry Location', style: TextStyle(color: Colors.white)),
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
          color: Colors.black.withOpacity(0.1), // Soft dark overlay
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.2),
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
    if (_dailyForecast == null || _dailyForecast!.isEmpty) return const SizedBox.shrink();

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
                    color: Colors.black.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        dayOfWeek,
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                      Icon(
                        _getWeatherIcon(weatherCode, 1), // Assume daytime icon for forecast summary
                        color: _calmIconYellow.withOpacity(0.8),
                        size: 32,
                      ),
                      Text(
                        '$maxTemp° / $minTemp°',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16),
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