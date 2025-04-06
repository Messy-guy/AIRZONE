import 'package:flutter/material.dart';

class AppNavigator {

  static void pushReplacement(BuildContext context,Widget widget) {
    Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => widget)
    );//Pushes a widget to stack and removes the previous one
  }

  static void push(BuildContext context,Widget widget) {
    Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => widget)
    );//pushes a widget to stack allowing user to access previous widget
  }

  static void pushAndRemove(BuildContext context,Widget widget) {
    Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => widget),
            (Route<dynamic> route) => false
    );//pushes a widget to stack and removes all previous widgets
  }
}