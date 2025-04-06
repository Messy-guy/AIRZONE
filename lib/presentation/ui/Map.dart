import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class FixedKathmanduAQIMap extends StatefulWidget {
  const FixedKathmanduAQIMap({Key? key}) : super(key: key);

  @override
  State<FixedKathmanduAQIMap> createState() => _FixedKathmanduAQIMapState();
}

class _FixedKathmanduAQIMapState extends State<FixedKathmanduAQIMap> {
  final String _apiKey = '8e20d345d6933be0fb73f1fa32b81295'; // Replace this
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
      }
    }

    setState(() {
      _cityMarkers = markers;
      _isLoading = false;
    });
  }

  Future<int> _fetchAqiForLocation(double lat, double lon) async {
    final url =
        "https://api.openweathermap.org/data/2.5/air_pollution?lat=$lat&lon=$lon&appid=$_apiKey";
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['list'][0]['main']['aqi'] ?? 0;
    }
    return 0;
  }

  Marker _buildCityMarker(String name, double lat, double lon, int aqi) {
    final color = _getColorForAqi(aqi);
    final aqiDescription = _getAqiDescription(aqi);

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
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
          children: [
            Text('AQI: $aqi', style: TextStyle(fontSize: 24, color: _getColorForAqi(aqi))),
            Text('Air Quality: $desc'),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('OK'))],
      ),
    );
  }

  Color _getColorForAqi(int aqi) {
    switch (aqi) {
      case 1: return Colors.green;
      case 2: return Colors.yellow;
      case 3: return Colors.orange;
      case 4: return Colors.red;
      case 5: return Colors.purple;
      default: return Colors.grey;
    }
  }

  String _getAqiDescription(int aqi) {
    switch (aqi) {
      case 1: return 'Good';
      case 2: return 'Fair';
      case 3: return 'Moderate';
      case 4: return 'Poor';
      case 5: return 'Very Poor';
      default: return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kathmandu Valley AQI"),
        centerTitle: true,
        actions: [
          IconButton(onPressed: _loadAqiForAllCities, icon: const Icon(Icons.refresh))
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
              ),
              MarkerLayer(markers: _cityMarkers),
            ],
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
