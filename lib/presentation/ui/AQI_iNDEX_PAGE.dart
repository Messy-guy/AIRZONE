import 'dart:convert';

import 'package:air_zone/core/navigator/app_navigator.dart';
import 'package:air_zone/presentation/ui/Map.dart';
import 'package:air_zone/restartapp.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';

class AqiIndexPage extends StatefulWidget {
  const AqiIndexPage({super.key});

  @override
  State<AqiIndexPage> createState() => _AqiIndexPageState();
}

class AqiData {
  final DateTime date;
  final String day;
  final int aqi;

  AqiData({
    required this.date,
    required this.day,
    required this.aqi,
  });
}

class _AqiIndexPageState extends State<AqiIndexPage> {
  int? _aqi;
  String _status = "Fetching data...";
  double? _longitude;
  double? _latitude;
  double? _co;
  double? _no;
  double? _no2;
  double? _o3;
  double? _so2;
  double? _pm2_5;
  double? _pm10;
  double? _nh3;
  String _cityName = "Loading...";
  List<AqiData> _weeklyAqi = [];
  bool _isLoading = true;
  bool _usingDefaultLocation = false;

  // Default location (Kathmandu)
  static const double _defaultLatitude = 27.7172;
  static const double _defaultLongitude = 85.3240;

  final String _apiKey = "8e20d345d6933be0fb73f1fa32b81295";
  final Location _location = Location();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    setState(() {
      _isLoading = true;
      _usingDefaultLocation = false;
    });

    try {
      // Try to get current location first
      await _tryGetCurrentLocation();
      
      // If we don't have location, use default
      if (_latitude == null || _longitude == null) {
        await _useDefaultLocation();
      }
      
      // Fetch data with whatever location we have
      await _fetchData();
    } catch (e) {
      // If anything fails, use default location
      await _useDefaultLocation();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _tryGetCurrentLocation() async {
    try {
      // Check if service is enabled
      bool serviceEnabled = await _location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _location.requestService();
        if (!serviceEnabled) return;
      }

      // Check permissions
      PermissionStatus permission = await _location.hasPermission();
      if (permission == PermissionStatus.denied) {
        permission = await _location.requestPermission();
        if (permission != PermissionStatus.granted) return;
      }

      // Get location
      LocationData locationData = await _location.getLocation().timeout(
        const Duration(seconds: 10),
      );

      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _latitude = locationData.latitude;
          _longitude = locationData.longitude;
          _usingDefaultLocation = false;
        });
      }
    } catch (e) {
      // Silently fail - we'll use default location
    }
  }

  Future<void> _useDefaultLocation() async {
    setState(() {
      _latitude = _defaultLatitude;
      _longitude = _defaultLongitude;
      _usingDefaultLocation = true;
    });
  }

  Future<void> _fetchData() async {
    try {
      await _fetchCurrentAqi();
      await _fetchWeeklyForecast();
    } catch (e) {
      setState(() {
        _status = "Data unavailable";
      });
    }
  }

  Future<void> _fetchCurrentAqi() async {
    final aqiUrl = Uri.parse(
      "https://api.openweathermap.org/data/2.5/air_pollution?lat=$_latitude&lon=$_longitude&appid=$_apiKey",
    );

    final nameUrl = Uri.parse(
      "https://api.openweathermap.org/data/2.5/weather?lat=$_latitude&lon=$_longitude&appid=$_apiKey",
    );

    try {
      final responseName = await http.get(nameUrl);
      if (responseName.statusCode == 200) {
        final dataName = jsonDecode(responseName.body);
        final cityName = dataName['name'] as String?;
        setState(() {
          _cityName = dataName['name'] as String? ?? "Current Location";
        });
      }

      final response = await http.get(aqiUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final listData = data['list'][0];
        
        setState(() {
          _aqi = listData['main']['aqi'] as int?;
          final components = listData['components'] as Map<String, dynamic>;
          _pm2_5 = components['pm2_5']?.toDouble();
          _aqi = _pm2_5 != null ? _calculateRealAqi(_pm2_5!) : null;
          
          _co = components['co']?.toDouble();
          _no = components['no']?.toDouble();
          _no2 = components['no2']?.toDouble();
          _o3 = components['o3']?.toDouble();
          _so2 = components['so2']?.toDouble();
          _pm2_5 = components['pm2_5']?.toDouble();
          _pm10 = components['pm10']?.toDouble();
          _nh3 = components['nh3']?.toDouble();

          _status = _getAqiStatus(_aqi);
        });
      }
    } catch (e) {
      setState(() {
        _status = "Data unavailable";
      });
    }
  }

  Future<void> _fetchWeeklyForecast() async {
    final forecastUrl = Uri.parse(
      "http://api.openweathermap.org/data/2.5/air_pollution/forecast?lat=$_latitude&lon=$_longitude&appid=$_apiKey",
    );

    try {
      final response = await http.get(forecastUrl);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> listData = data['list'];

        Map<String, List<double>> dailyAqi = {};
        
        for (var item in listData) {
          final date = DateTime.fromMillisecondsSinceEpoch(item['dt'] * 1000);
          final dayKey = "${date.year}-${date.month}-${date.day}";
          final pm2_5 = item['components']['pm2_5']?.toDouble() ?? 0;
          final aqi = _calculateRealAqi(pm2_5);
          
          if (!dailyAqi.containsKey(dayKey)) {
            dailyAqi[dayKey] = [];
          }
          dailyAqi[dayKey]!.add(aqi.toDouble());
        }

        List<AqiData> weeklyData = [];
        dailyAqi.forEach((day, aqiValues) {
          final dateParts = day.split('-');
          final date = DateTime(
            int.parse(dateParts[0]), 
            int.parse(dateParts[1]), 
            int.parse(dateParts[2])
          );
          
          weeklyData.add(AqiData(
            date: date,
            day: _getDayName(date.weekday),
            aqi: (aqiValues.reduce((a, b) => a + b) / aqiValues.length).round(),
          ));
        });

        setState(() {
          _weeklyAqi = weeklyData.take(7).toList();
        });
      }
    } catch (e) {
      // Silently fail - forecast is secondary data
    }
  }

  int _calculateRealAqi(double pm2_5) {
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

  String _getAqiStatus(int? aqi) {
    if (aqi == null) return "Unknown";
    if (aqi <= 50) return "Good";
    if (aqi <= 100) return "Moderate";
    if (aqi <= 150) return "Unhealthy for Sensitive Groups";
    if (aqi <= 200) return "Unhealthy";
    if (aqi <= 300) return "Very Unhealthy";
    return "Hazardous";
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1: return 'Mon';
      case 2: return 'Tue';
      case 3: return 'Wed';
      case 4: return 'Thu';
      case 5: return 'Fri';
      case 6: return 'Sat';
      case 7: return 'Sun';
      default: return '';
    }
  }

  Color _getAqiColor(int? aqi) {
    aqi ??= 0;
    if (aqi <= 50) return Colors.green;
    if (aqi <= 100) return Colors.yellow;
    if (aqi <= 150) return Colors.orange;
    if (aqi <= 200) return Colors.red;
    if (aqi <= 300) return Colors.purple;
    return Colors.brown;
  }

  Widget _buildPollutantCard(String name, double? value, String unit) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value?.toStringAsFixed(2) ?? 'N/A',
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  unit,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("AirZone"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeApp,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.location_on, size: 20),
                  onPressed: () {
                      AppNavigator.push(context, FixedKathmanduAQIMap());
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  _cityName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  if (_usingDefaultLocation)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.info_outline, color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          const Text("Using default location"),
                          TextButton(
                            onPressed: _initializeApp,
                            child: const Text("Try again"),
                          ),
                        ],
                      ),
                    ),
                  
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Center(
                      child: Container(
                        height: MediaQuery.of(context).size.height * 0.2,
                        width: MediaQuery.of(context).size.width * 0.45,
                        decoration: BoxDecoration(
                          color: _getAqiColor(_aqi),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              spreadRadius: 3,
                              blurRadius: 4,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _aqi?.toString() ?? 'N/A',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _status,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 243, 242, 242),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 3,
                          blurRadius: 4,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Text(
                            "Pollutants Levels",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(20),
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.5,
                          children: [
                            _buildPollutantCard('CO', _co, 'μg/m³'),
                            _buildPollutantCard('NO', _no, 'μg/m³'),
                            _buildPollutantCard('NO₂', _no2, 'μg/m³'),
                            _buildPollutantCard('O₃', _o3, 'μg/m³'),
                            _buildPollutantCard('SO₂', _so2, 'μg/m³'),
                            _buildPollutantCard('PM2.5', _pm2_5, 'μg/m³'),
                            _buildPollutantCard('PM10', _pm10, 'μg/m³'),
                            _buildPollutantCard('NH₃', _nh3, 'μg/m³'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.9,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 243, 242, 242),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          spreadRadius: 3,
                          blurRadius: 4,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Text(
                            "7-Day AQI Forecast",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: SizedBox(
                            height: 250,
                            child: _weeklyAqi.isNotEmpty
                                ? SfCartesianChart(
                                    primaryXAxis: CategoryAxis(
                                      title: AxisTitle(text: 'Day'),
                                    ),
                                    primaryYAxis: NumericAxis(
                                      title: AxisTitle(text: 'AQI'),
                                      minimum: 0,
                                      maximum: _weeklyAqi
                                              .map((e) => e.aqi)
                                              .reduce((a, b) => a > b ? a : b) *
                                          1.1,
                                    ),
                                    series: <CartesianSeries<AqiData, String>>[
                                      LineSeries<AqiData, String>(
                                        dataSource: _weeklyAqi,
                                        xValueMapper: (AqiData data, _) => data.day,
                                        yValueMapper: (AqiData data, _) => data.aqi,
                                        dataLabelSettings:
                                            const DataLabelSettings(isVisible: true),
                                        color: Colors.blue,
                                        markerSettings:
                                            const MarkerSettings(isVisible: true),
                                      )
                                    ],
                                  )
                                : const Center(
                                    child: Text("No forecast data available"),
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 20.0),
                          child: Wrap(
                            spacing: 10,
                            children: _weeklyAqi
                                .map((data) => Chip(
                                      backgroundColor: _getAqiColor(data.aqi),
                                      label: Text(
                                        "${data.day}: ${data.aqi}",
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
    );
  }
}