class DatasetProvenanceSummary {
  final int count;
  final String description;

  DatasetProvenanceSummary({required this.count, required this.description});

  factory DatasetProvenanceSummary.fromJson(Map<dynamic, dynamic> json) {
    return DatasetProvenanceSummary(
      count: (json['count'] as num?)?.toInt() ?? 0,
      description: json['description'] as String? ?? '',
    );
  }
}

class HistoryAvailabilityResponse {
  final String status;
  final int totalRecords;
  final DateTime? oldestRecord;
  final DateTime? newestRecord;
  final int physicalStationRecords;
  final int modelDerivedRecords;
  final int syntheticDemoRecords;
  final int uniqueStationsCount;
  final Map<String, DatasetProvenanceSummary> provenanceSummary;

  HistoryAvailabilityResponse({
    required this.status,
    required this.totalRecords,
    this.oldestRecord,
    this.newestRecord,
    required this.physicalStationRecords,
    required this.modelDerivedRecords,
    required this.syntheticDemoRecords,
    required this.uniqueStationsCount,
    required this.provenanceSummary,
  });

  factory HistoryAvailabilityResponse.fromJson(Map<dynamic, dynamic> json) {
    final provMap = <String, DatasetProvenanceSummary>{};
    if (json['provenance_summary'] is Map) {
      (json['provenance_summary'] as Map).forEach((k, v) {
        if (v is Map) {
          provMap[k.toString()] = DatasetProvenanceSummary.fromJson(v);
        }
      });
    }

    return HistoryAvailabilityResponse(
      status: json['status'] as String? ?? 'ACTIVE',
      totalRecords: (json['total_records'] as num?)?.toInt() ?? 0,
      oldestRecord: json['oldest_record'] != null
          ? DateTime.parse(json['oldest_record'] as String)
          : null,
      newestRecord: json['newest_record'] != null
          ? DateTime.parse(json['newest_record'] as String)
          : null,
      physicalStationRecords: (json['physical_station_records'] as num?)?.toInt() ?? 0,
      modelDerivedRecords: (json['model_derived_records'] as num?)?.toInt() ?? 0,
      syntheticDemoRecords: (json['synthetic_demo_records'] as num?)?.toInt() ?? 0,
      uniqueStationsCount: (json['unique_stations_count'] as num?)?.toInt() ?? 0,
      provenanceSummary: provMap,
    );
  }
}
