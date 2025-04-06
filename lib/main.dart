import 'package:air_zone/presentation/ui/AQI_iNDEX_PAGE.dart';
import 'package:air_zone/restartapp.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(RestartWidget(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AqiIndexPage(),
    );
  }
}