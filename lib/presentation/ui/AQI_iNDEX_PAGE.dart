import 'dart:convert';

import 'package:air_zone/core/navigator/app_navigator.dart';
import 'package:air_zone/presentation/ui/Map.dart';
import 'package:air_zone/restartapp.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;

class AqiIndexPage extends StatefulWidget {
  const AqiIndexPage({super.key});

  @override
  State<AqiIndexPage> createState() => _AqiIndexPageState();
}

class _AqiIndexPageState extends State<AqiIndexPage> {
  int? _aqi; //to store the air quality index
  String _status = "Fetching data..."; //to store the status of the air quality index
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
  String _cityName = "Fetching data..."; //to store the city name

  final String _apiKey = "8e20d345d6933be0fb73f1fa32b81295"; //API key for the air quality index API

  @override
  void initState() {
    super.initState();
    _fetchAQIdata();
  }

  Future<void> _fetchAQIdata() async {
    try {
      // Phase 1: Get user Location
      Location location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          setState(() {
            _status = "Location service is disabled";
          });
          return;
        }
      }

      // Phase 2: Check for permission
      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          setState(() {
            _status = "Location permission denied";
          });
          return;
        }
      }

      // Get location data
      LocationData locData = await location.getLocation();
      setState(() {
        _longitude = locData.longitude;
        _latitude = locData.latitude;
      });

      // Phase 3: Fetch data from API
      final AQIurl = Uri.parse(
        "http://api.openweathermap.org/data/2.5/air_pollution?lat=$_latitude&lon=$_longitude&appid=$_apiKey",
      );

      final NameUrl = Uri.parse("https://api.openweathermap.org/data/2.5/weather?lat=$_latitude&lon=$_longitude&appid=$_apiKey");

      final responseName = await http.get(NameUrl);
      if(responseName.statusCode == 200){
        final dataName = jsonDecode(responseName.body);
        final cityName = dataName['name'] as String?;
        setState(() {
          _cityName = cityName ?? "Unknown City";
        });
      }

      final response = await http.get(AQIurl);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final listData = data['list'][0];
        
        setState(() {
          _aqi = listData['main']['aqi'] as int?;
          final components = listData['components'] as Map<String, dynamic>;
          
          _co = components['co']?.toDouble();
          _no = components['no']?.toDouble();
          _no2 = components['no2']?.toDouble();
          _o3 = components['o3']?.toDouble();
          _so2 = components['so2']?.toDouble();
          _pm2_5 = components['pm2_5']?.toDouble();
          _pm10 = components['pm10']?.toDouble();
          _nh3 = components['nh3']?.toDouble();

          // Update status based on AQI
          switch (_aqi) {
            case 1:
              _status = "Good";
              break;
            case 2:
              _status = "Fair";
              break;
            case 3:
              _status = "Moderate";
              break;
            case 4:
              _status = "Poor";
              break;
            case 5:
              _status = "Very Poor";
              break;
            default:
              _status = "Unknown";
          }
        });
      } else {
        setState(() {
          _status = "Failed to fetch data (${response.statusCode})";
        });
      }
    } catch (e) {
      setState(() {
        _status = "Error: ${e.toString()}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed:(){
              _fetchAQIdata();
            }
          ), // Location icon
        ],
        bottom:PreferredSize(
          preferredSize: Size.fromHeight(40),
         child: Padding(
           padding: const EdgeInsets.all(8.0),
           child: Row(
            children: [
               IconButton(
            icon: const Icon(Icons.location_on),
            onPressed:(){
             if(_latitude != null && _longitude != null){
                AppNavigator.push(context, FixedKathmanduAQIMap());
            }else{
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Location not available")),
              );}
            }
          ), 
                    SizedBox(width: 8), // Space between icon and text
                    Text(
                      '$_cityName',  // This will be your dynamic city name
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
            ],
                   ),
         )),
        backgroundColor: const Color.fromARGB(255, 197, 193, 193),
        title: const Text("AirZone"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 30),
            child: Center(
              child: Container(
                height: MediaQuery.of(context).size.height * 0.2,
                width: MediaQuery.of(context).size.width * 0.45,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 243, 242, 242),
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
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _status,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Container(
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
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: GridView.count(
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
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
}