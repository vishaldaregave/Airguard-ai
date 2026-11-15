import 'package:flutter/material.dart';

class AppColors {
  // Background & Surface
  static const Color background = Color(0xFF090D16);
  static const Color surface = Color(0xFF111827);
  static const Color surfaceElevated = Color(0xFF182234);
  static const Color surfaceCard = Color(0xFF131D2E);
  static const Color border = Color(0xFF223049);
  static const Color borderHighlight = Color(0xFF334766);

  // Futuristic Accents
  static const Color emeraldAccent = Color(0xFF00E5A3);
  static const Color cyanAccent = Color(0xFF00D2FF);
  static const Color cobaltAccent = Color(0xFF3B82F6);
  static const Color purpleAccent = Color(0xFF8B5CF6);

  // Text
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // CPCB Official AQI Color Scale
  static const Color aqiGood = Color(0xFF00E5A3);         // Good (0-50)
  static const Color aqiSatisfactory = Color(0xFF84CC16); // Satisfactory (51-100)
  static const Color aqiModerate = Color(0xFFFBBF24);     // Moderate (101-200)
  static const Color aqiPoor = Color(0xFFFB923C);         // Poor (201-300)
  static const Color aqiVeryPoor = Color(0xFFEF4444);     // Very Poor (301-400)
  static const Color aqiSevere = Color(0xFF991B1B);       // Severe (401-500)

  // Data Provenance Badges (Strictly Distinguished)
  static const Color liveBadge = Color(0xFF10B981);       // Verified ground monitoring
  static const Color estimatedBadge = Color(0xFF06B6D4);  // Model-derived estimate
  static const Color forecastBadge = Color(0xFF8B5CF6);   // Forecast projection
  static const Color historicalBadge = Color(0xFF64748B); // Historical record
  static const Color fixtureBadge = Color(0xFFF59E0B);    // Synthetic demo fixture
  static const Color staleBadge = Color(0xFFEF4444);      // Exceeds freshness threshold

  static Color getAqiColor(int? aqi) {
    if (aqi == null) return textMuted;
    if (aqi <= 50) return aqiGood;
    if (aqi <= 100) return aqiSatisfactory;
    if (aqi <= 200) return aqiModerate;
    if (aqi <= 300) return aqiPoor;
    if (aqi <= 400) return aqiVeryPoor;
    return aqiSevere;
  }

  static Color getProvenanceColor(String dataSourceType) {
    switch (dataSourceType.toUpperCase()) {
      case 'LIVE':
        return liveBadge;
      case 'ESTIMATED':
        return estimatedBadge;
      case 'FORECAST':
        return forecastBadge;
      case 'HISTORICAL':
        return historicalBadge;
      case 'DEMO_FIXTURE':
      default:
        return fixtureBadge;
    }
  }
}
