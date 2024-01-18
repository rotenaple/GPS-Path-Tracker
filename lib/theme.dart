import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColour = Color(0xFFFFD300); //Flinders Gold
  static const Color backgroundColour = Color(0xFFFFFFFF);
  static const Color textColour = Color(0xFF232D4B); //Flinders Navy
  static const Color unselectedColour = Color(0xFFAAAAAA);
  static const Color warningColour = Color(0xFFF44336);
  static const Color flindersDust = Color(0xFFF6EEE1); //Flinders Dust

  /*static const Color primaryColour = Color(0xFF002EA9);
  static const Color backgroundColour = Color(0xFFFFFFFF);
  static const Color textColour = Color(0xFF232D4B);
  static const Color unselectedColour = Color(0xFFAAAAAA);
  static const Color warningColour = Color(0xFFF44336);*/

  static const Color iconColor = textColour;

  static const TextStyle listItemTextStyle = TextStyle(
    color: textColour,
    fontFamily: 'DMSans',
  );

  static const TextStyle headerStyle = TextStyle(
    color: textColour,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    fontFamily: 'DMSans',
  );

  static const TextStyle subtitleStyle = TextStyle(
    color: textColour,
    fontFamily: 'DMSans',
  );

  static const TextStyle normalTextStyle = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 14,
    color: textColour,
    fontFamily: 'DMSans',
  );

  static const TextStyle boldTextStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 14,
    color: textColour,
    fontFamily: 'DMSans',
  );

  static const TextStyle h1 = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 48,
    color: AppTheme.textColour,
    fontFamily: 'DMSans',
  );

  static const TextStyle h2 = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 24,
    color: AppTheme.textColour,
    fontFamily: 'DMSans',
  );

  static const TextStyle h3 = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 18,
    color: AppTheme.textColour,
    fontFamily: 'DMSans',
  );

  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    //foregroundColor: textColour,
    //backgroundColor: primaryColour,

    foregroundColor: textColour,
    backgroundColor: primaryColour,
  );

  static Widget styledContainer({required Widget child}) {
    return Card(
      color: flindersDust,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }

  static const TextStyle dialogTitleStyle = TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 18,
    color: textColour,
    fontFamily: 'DMSans',
  );

  static const TextStyle dialogContentStyle = TextStyle(
    fontWeight: FontWeight.w500,
    fontSize: 16,
    color: textColour,
    fontFamily: 'DMSans',
  );

  static const TextStyle dialogButtonStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: textColour,
    fontFamily: 'DMSans',
  );

  static const TextStyle dialogAlertButtonStyle = TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: 16,
    color: warningColour,
    fontFamily: 'DMSans',
  );

  static const TextStyle creditTextStyle = TextStyle(
    fontSize: 12,
    color: unselectedColour,
    fontFamily: 'DMSans',
  );

  static void showSnackbar(BuildContext context, String message,
      {Duration duration = const Duration(seconds: 5)}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: AppTheme.backgroundColour),
        ),
        duration: duration,
      ),
    );
  }
}

class ReturnOS {
  String returnOS(){
    String platform = "web";
    if (!kIsWeb){
      if (Platform.isAndroid) platform = "android";
      else if (Platform.isWindows) platform = "windows";
      else platform = "other non-web";
    }

    return platform;
  }
}
