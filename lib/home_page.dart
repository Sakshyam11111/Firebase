import 'package:assignment_firebase/login.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'auth_service.dart';

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto',
      ),
      home: const WeatherHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class WeatherHomePage extends StatefulWidget {
  const WeatherHomePage({super.key});

  @override
  _WeatherHomePageState createState() => _WeatherHomePageState();
}

class _WeatherHomePageState extends State<WeatherHomePage> 
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final AuthService _authService = AuthService();
  String _city = 'London';
  Map<String, dynamic>? _currentWeather;
  List<dynamic>? _forecast;
  bool _isLoading = false;
  String _errorMessage = '';
  
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _fetchWeatherData(_city);
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutBack));
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Color _getWeatherColor(String? condition) {
    if (condition == null) return Colors.blue;
    switch (condition.toLowerCase()) {
      case 'clear':
        return Colors.orange;
      case 'clouds':
        return Colors.grey;
      case 'rain':
        return Colors.indigo;
      case 'snow':
        return Colors.lightBlue;
      case 'thunderstorm':
        return Colors.deepPurple;
      default:
        return Colors.blue;
    }
  }

  List<Color> _getGradientColors() {
    if (_currentWeather == null) return [Colors.blue[400]!, Colors.blue[800]!];
    
    final condition = _currentWeather!['weather'][0]['main'];
    final isDay = DateTime.now().hour > 6 && DateTime.now().hour < 18;
    
    if (isDay) {
      switch (condition.toLowerCase()) {
        case 'clear':
          return [Colors.orange[300]!, Colors.orange[600]!, Colors.red[400]!];
        case 'clouds':
          return [Colors.grey[400]!, Colors.grey[600]!, Colors.blueGrey[700]!];
        case 'rain':
          return [Colors.indigo[400]!, Colors.indigo[700]!, Colors.blue[900]!];
        case 'snow':
          return [Colors.lightBlue[200]!, Colors.lightBlue[400]!, Colors.blue[600]!];
        default:
          return [Colors.blue[400]!, Colors.blue[600]!, Colors.purple[600]!];
      }
    } else {
      return [Colors.indigo[800]!, Colors.purple[900]!, Colors.black87];
    }
  }

  Future<void> _fetchWeatherData(String city) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final geoUrl = 'http://api.openweathermap.org/geo/1.0/direct?q=$city&limit=1&appid=beb68caa757def4aad48a4d473795f8a';
      final geoResponse = await http.get(Uri.parse(geoUrl));
      if (geoResponse.statusCode != 200) {
        throw Exception('Failed to fetch city coordinates. Please try again.');
      }

      final geoData = json.decode(geoResponse.body);
      if (geoData.isEmpty) {
        throw Exception('City not found. Please check the city name.');
      }

      final lat = geoData[0]['lat'];
      final lon = geoData[0]['lon'];

      final weatherUrl = 'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=beb68caa757def4aad48a4d473795f8a&units=metric';
      final weatherResponse = await http.get(Uri.parse(weatherUrl));
      if (weatherResponse.statusCode != 200) {
        throw Exception('Failed to fetch weather data. Please try again.');
      }

      final forecastUrl = 'https://api.openweathermap.org/data/2.5/forecast?lat=$lat&lon=$lon&appid=beb68caa757def4aad48a4d473795f8a&units=metric';
      final forecastResponse = await http.get(Uri.parse(forecastUrl));
      if (forecastResponse.statusCode != 200) {
        throw Exception('Failed to fetch forecast data. Please try again.');
      }

      setState(() {
        _currentWeather = json.decode(weatherResponse.body);
        _forecast = json.decode(forecastResponse.body)['list'];
        _city = city;
        _isLoading = false;
      });
      
      _slideController.reset();
      _slideController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchWeatherForCurrentLocation() async {
    HapticFeedback.lightImpact();
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled. Please enable them in settings.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions denied. Please allow location access.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions permanently denied. Please enable in settings.');
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final weatherUrl =
          'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=beb68caa757def4aad48a4d473795f8a&units=metric';
      final weatherResponse = await http.get(Uri.parse(weatherUrl));
      if (weatherResponse.statusCode != 200) {
        throw Exception('Failed to fetch weather data for current location.');
      }

      final forecastUrl =
          'https://api.openweathermap.org/data/2.5/forecast?lat=${position.latitude}&lon=${position.longitude}&appid=beb68caa757def4aad48a4d473795f8a&units=metric';
      final forecastResponse = await http.get(Uri.parse(forecastUrl));
      if (forecastResponse.statusCode != 200) {
        throw Exception('Failed to fetch forecast data for current location.');
      }

      setState(() {
        _currentWeather = json.decode(weatherResponse.body);
        _forecast = json.decode(forecastResponse.body)['list'];
        _city = _currentWeather!['name'] ?? 'Current Location';
        _isLoading = false;
      });
      
      _slideController.reset();
      _slideController.forward();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _signOut() async {
    HapticFeedback.mediumImpact();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout, color: Colors.red),
            SizedBox(width: 8),
            Text('Sign Out'),
          ],
        ),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _authService.signOut();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                }
              } catch (e) {
                setState(() {
                  _errorMessage = 'Error signing out: $e';
                });
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                hintText: 'Search for a city...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.8)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  HapticFeedback.lightImpact();
                  _fetchWeatherData(value);
                  _searchController.clear();
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: IconButton(
                    onPressed: _fetchWeatherForCurrentLocation,
                    icon: const Icon(Icons.my_location, color: Colors.white, size: 24),
                    tooltip: 'Use Current Location',
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentWeatherCard() {
    if (_currentWeather == null) return const SizedBox();

    final temp = _currentWeather!['main']['temp'].round();
    final description = _currentWeather!['weather'][0]['description'];
    final icon = _currentWeather!['weather'][0]['icon'];

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 20),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: Colors.white.withOpacity(0.8), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _city,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Image.network(
                    'http://openweathermap.org/img/wn/$icon@2x.png',
                    width: 120,
                    height: 120,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: const Icon(Icons.wb_sunny, size: 60, color: Colors.white),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              '${temp}°C',
              style: const TextStyle(
                fontSize: 64,
                fontWeight: FontWeight.w300,
                color: Colors.white,
                height: 1,
              ),
            ),
            Text(
              description.toUpperCase(),
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.9),
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeatherStat(
                  Icons.water_drop,
                  'Humidity',
                  '${_currentWeather!['main']['humidity']}%',
                ),
                _buildWeatherStat(
                  Icons.air,
                  'Wind',
                  '${_currentWeather!['wind']['speed']} m/s',
                ),
                _buildWeatherStat(
                  Icons.visibility,
                  'Visibility',
                  '${(_currentWeather!['visibility'] / 1000).toStringAsFixed(1)} km',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildWeatherStat(
                  Icons.thermostat,
                  'Feels Like',
                  '${_currentWeather!['main']['feels_like'].round()}°C',
                ),
                _buildWeatherStat(
                  Icons.compress,
                  'Pressure',
                  '${_currentWeather!['main']['pressure']} hPa',
                ),
                _buildWeatherStat(
                  Icons.wb_sunny_outlined,
                  'UV Index',
                  'N/A',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeatherStat(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.8), size: 20),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildForecastSection() {
    if (_forecast == null) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 16),
          child: Row(
            children: [
              Icon(Icons.calendar_today, color: Colors.white.withOpacity(0.8), size: 20),
              const SizedBox(width: 8),
              const Text(
                '5-Day Forecast',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        ..._buildForecastCards(),
      ],
    );
  }

  List<Widget> _buildForecastCards() {
    if (_forecast == null) return [];
    
    Map<String, List<dynamic>> dailyForecasts = {};
    for (var item in _forecast!) {
      String date = item['dt_txt'].split(' ')[0];
      if (!dailyForecasts.containsKey(date)) {
        dailyForecasts[date] = [];
      }
      dailyForecasts[date]!.add(item);
    }

    List<Widget> widgets = [];
    int index = 0;
    
    dailyForecasts.forEach((date, forecasts) {
      if (index < 5) {
        widgets.add(
          AnimatedContainer(
            duration: Duration(milliseconds: 300 + (index * 100)),
            margin: const EdgeInsets.only(bottom: 12),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                childrenPadding: const EdgeInsets.all(16),
                backgroundColor: Colors.transparent,
                collapsedBackgroundColor: Colors.transparent,
                iconColor: Colors.white,
                collapsedIconColor: Colors.white.withOpacity(0.8),
                title: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Image.network(
                        'http://openweathermap.org/img/wn/${forecasts[0]['weather'][0]['icon']}.png',
                        width: 32,
                        height: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDate(date),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            forecasts[0]['weather'][0]['description'],
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '${forecasts[0]['main']['temp'].round()}°C',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                children: forecasts.take(6).map((forecast) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Text(
                          forecast['dt_txt'].split(' ')[1].substring(0, 5),
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Image.network(
                          'http://openweathermap.org/img/wn/${forecast['weather'][0]['icon']}.png',
                          width: 24,
                          height: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${forecast['main']['temp'].round()}°C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        );
        index++;
      }
    });

    return widgets;
  }

  String _formatDate(String date) {
    final dateTime = DateTime.parse(date);
    final now = DateTime.now();
    final tomorrow = now.add(const Duration(days: 1));
    
    if (dateTime.day == now.day && dateTime.month == now.month) {
      return 'Today';
    } else if (dateTime.day == tomorrow.day && dateTime.month == tomorrow.month) {
      return 'Tomorrow';
    } else {
      const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      return '${days[dateTime.weekday % 7]}, ${months[dateTime.month - 1]} ${dateTime.day}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text(
          'Weather',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.3)),
            ),
            child: IconButton(
              icon: const Icon(Icons.logout, color: Colors.white),
              onPressed: _signOut,
              tooltip: 'Sign Out',
            ),
          ),
        ],
      ),
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 1000),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _getGradientColors(),
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildSearchBar(),
                ),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SpinKitRing(
                                color: Colors.white,
                                size: 60.0,
                                lineWidth: 4.0,
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading weather data...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _errorMessage.isNotEmpty
                          ? Center(
                              child: Container(
                                margin: const EdgeInsets.all(20),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      _errorMessage,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      onPressed: () {
                                        if (_errorMessage.contains('City not found')) {
                                          _fetchWeatherData(_searchController.text);
                                        } else {
                                          _fetchWeatherForCurrentLocation();
                                        }
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Try Again'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        foregroundColor: Colors.red,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(15),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                children: [
                                  _buildCurrentWeatherCard(),
                                  _buildForecastSection(),
                                  const SizedBox(height: 20),
                                ],
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
}