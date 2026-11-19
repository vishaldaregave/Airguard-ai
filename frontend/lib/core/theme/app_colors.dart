import 'package:flutter/material.dart';

class AppColors {
  // Atmospheric Sky-Blue Palette (Inspired by Dribbble UI)
  static const Color background = Color(0xFFF1F6FD);
  // Base tint behind the cloudy sky backdrop.
  static const Color skyBase = Color(0xFFE9F3FC);
  static const Color cloudTint = Color(0xFFFFFFFF);
  static const Color backgroundGradientStart = Color(0xFFE8F2FC);
  static const Color backgroundGradientEnd = Color(0xFFD4E7F8);

  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFF8FAFC);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfacePill = Color(0xFFEDF5FD);

  static const Color border = Color(0xFFE2EBF5);
  static const Color borderLight = Color(0xFFEEF4FA);
  static const Color borderHighlight = Color(0xFFBFDBFE);

  // Modern Accent Colors
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color skyBlue = Color(0xFF0284C7);
  static const Color cobaltAccent = Color(0xFF2563EB);
  static const Color emeraldAccent = Color(0xFF10B981);
  static const Color cyanAccent = Color(0xFF06B6D4);
  static const Color purpleAccent = Color(0xFF8B5CF6);
  static const Color amberAccent = Color(0xFFF59E0B);

  // Modern Typography Colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textLight = Color(0xFFF8FAFC);

  // CPCB Official AQI Color Scale
  static const Color aqiGood = Color(0xFF10B981);         // Good (0-50)
  static const Color aqiSatisfactory = Color(0xFF84CC16); // Satisfactory (51-100)
  static const Color aqiModerate = Color(0xFFF59E0B);     // Moderate (101-200)
  static const Color aqiPoor = Color(0xFFF97316);         // Poor (201-300)
  static const Color aqiVeryPoor = Color(0xFFEF4444);     // Very Poor (301-400)
  static const Color aqiSevere = Color(0xFF991B1B);       // Severe (401-500)

  // Data Provenance Badges (Strictly Distinguished)
  static const Color liveBadge = Color(0xFF10B981);       // Verified ground monitoring
  static const Color estimatedBadge = Color(0xFF0284C7);  // Model-derived estimate
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

  static List<BoxShadow> get cardShadow => [
    const BoxShadow(
      color: Color(0x0A1E3A8A),
      blurRadius: 16,
      spreadRadius: 0,
      offset: Offset(0, 3),
    ),
    const BoxShadow(
      color: Color(0x050F172A),
      blurRadius: 2,
      spreadRadius: 0,
      offset: Offset(0, 1),
    ),
  ];
}
