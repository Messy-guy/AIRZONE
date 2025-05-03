import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class FixedKathmanduAQIMap extends StatefulWidget {
  const FixedKathmanduAQIMap({super.key});

  @override
  State<FixedKathmanduAQIMap> createState() => _FixedKathmanduAQIMapState();
}

class _FixedKathmanduAQIMapState extends State<FixedKathmanduAQIMap> {
  final String _apiKey = '8e20d345d6933be0fb73f1fa32b81295'; // Replace with your API key
  List<Marker> _cityMarkers = [];
  bool _isLoading = true;

  final List<Map<String, dynamic>> _kathmanduValleyCities = [
    {'name': 'Kathmandu', 'lat': 27.7172, 'lon': 85.3240},
    {'name': 'Patan', 'lat': 27.6730, 'lon': 85.3240},
    {'name': 'Bhaktapur', 'lat': 27.6710, 'lon': 85.4298},
    {'name': 'Kirtipur', 'lat': 27.6656, 'lon': 85.2799},
    {'name': 'Lubhu', 'lat': 27.6424, 'lon': 85.3633},
    {'name': 'Tokha', 'lat': 27.7635, 'lon': 85.3264},
    {'name': 'Bungamati', 'lat': 27.6306, 'lon': 85.3080},
    {'name': 'Sankhu', 'lat': 27.7442, 'lon': 85.4585},
    {'name': 'Dhulikhel', 'lat': 27.6220, 'lon': 85.5415},
    {'name': 'Sundarijal', 'lat': 27.7933, 'lon': 85.4012},
  ];

  @override
  void initState() {
    super.initState();
    _loadAqiForAllCities();
  }

  Future<void> _loadAqiForAllCities() async {
    setState(() => _isLoading = true);
    List<Marker> markers = [];

    for (var city in _kathmanduValleyCities) {
      try {
        int aqi = await _fetchAqiForLocation(city['lat'], city['lon']);
        markers.add(_buildCityMarker(city['name'], city['lat'], city['lon'], aqi));
      } catch (e) {
        debugPrint("Error for ${city['name']}: $e");
        // Add marker with unknown AQI if there's an error
        markers.add(_buildCityMarker(city['name'], city['lat'], city['lon'], -1));
      }
    }

    setState(() {
      _cityMarkers = markers;
      _isLoading = false;
    });
  }

  Future<int> _fetchAqiForLocation(double lat, double lon) async {
    final url = Uri.parse(
      "https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$_apiKey",
    );
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final pm2_5 = json['list'][0]['components']['pm2_5']?.toDouble() ?? 0;
      return _calculateAqiFromPm2_5(pm2_5);
    }
    throw Exception('Failed to load AQI data');
  }

  int _calculateAqiFromPm2_5(double pm2_5) {
    if (pm2_5 <= 12.0) return _linearInterpolation(pm2_5, 0, 50, 0, 12.0);
    if (pm2_5 <= 35.4) return _linearInterpolation(pm2_5, 51, 100, 12.1, 35.4);
    if (pm2_5 <= 55.4) return _linearInterpolation(pm2_5, 101, 150, 35.5, 55.4);
    if (pm2_5 <= 150.4) return _linearInterpolation(pm2_5, 151, 200, 55.5, 150.4);
    if (pm2_5 <= 250.4) return _linearInterpolation(pm2_5, 201, 300, 150.5, 250.4);
    return _linearInterpolation(pm2_5, 301, 500, 250.5, 500.4);
  }

  int _linearInterpolation(double c, int aqiLow, int aqiHigh, double concLow, double concHigh) {
    return (((aqiHigh - aqiLow) / (concHigh - concLow)) * (c - concLow) + aqiLow).round();
  }

  Marker _buildCityMarker(String name, double lat, double lon, int aqi) {
    final color = _getColorForAqi(aqi);
    final aqiDescription = _getAqiDescription(aqi);
    final aqiText = aqi == -1 ? 'N/A' : aqi.toString();

    return Marker(
      width: 120.0,
      height: 120.0,
      point: LatLng(lat, lon),
      child: GestureDetector(
        onTap: () => _showCityInfo(name, aqi, aqiDescription),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_on, color: color, size: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'AQI: $aqiText',
                    style: TextStyle(
                      fontSize: 10,
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCityInfo(String name, int aqi, String desc) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (aqi == -1)
              const Text('AQI data not available', style: TextStyle(fontSize: 18))
            else ...[
              Text(
                'AQI: $aqi',
                style: TextStyle(
                  fontSize: 24,
                  color: _getColorForAqi(aqi),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Air Quality: $desc',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _getHealthImplications(aqi),
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _getColorForAqi(int aqi) {
    if (aqi == -1) return Colors.grey;
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }

  String _getAqiDescription(int aqi) {
    if (aqi == -1) return 'Data unavailable';
    if (aqi <= 50) return 'Good';
    if (aqi <= 100) return 'Moderate';
    if (aqi <= 150) return 'Unhealthy for Sensitive Groups';
    if (aqi <= 200) return 'Unhealthy';
    if (aqi <= 300) return 'Very Unhealthy';
    return 'Hazardous';
  }

  String _getHealthImplications(int aqi) {
    if (aqi == -1) return '';
    if (aqi <= 50) return 'Air quality is satisfactory with little health risk.';
    if (aqi <= 100) return 'Acceptable quality, but some pollutants may affect sensitive individuals.';
    if (aqi <= 150) return 'Sensitive groups may experience health effects.';
    if (aqi <= 200) return 'Everyone may begin to experience health effects.';
    if (aqi <= 300) return 'Health alert: everyone may experience more serious health effects.';
    return 'Health warnings of emergency conditions.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kathmandu Valley AQI Map"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAqiForAllCities,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(27.7172, 85.3240),
              initialZoom: 11,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.air_zone',
              ),
              MarkerLayer(markers: _cityMarkers),
            ],
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }
}