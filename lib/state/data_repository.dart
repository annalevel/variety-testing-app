import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:variety_testing_app/state/csv_manager.dart';
import 'package:variety_testing_app/state/local_storage_service.dart';
import '../models/data_set.dart';
import '../models/observation.dart';
import '../models/trait.dart';

class DataRepository extends ChangeNotifier {
  final CSVManager csvManager;
  final LocalStorageService localStorageService;
  String? lastUpdated;
  String? dataYear;

  List<DataSet> dataSets = [];

  DataRepository(this.csvManager, this.localStorageService);

  // DataRepository will initialize and coordinate all of the data fetching.
  Future<void> initializeData() async {
    try {
      dataYear = await retrieveDataYear();
      lastUpdated = await retrieveLastUpdated();
      dataSets = await retrieveStateFromLocalStorage() ?? [];

      await csvManager.getIndexFileData();
      String newLastUpdated = csvManager.getLastUpdated();
      String newDataYear = csvManager.getDataYear();

      // We should use the local data if the data set isn't updated from last time,
      // or the index file couldn't be fetched.
      if (dataYear == "" || lastUpdated == "" || (newLastUpdated == lastUpdated && newDataYear == dataYear)) {
        if (dataSets.isNotEmpty) {
          return;
        }
      }

      lastUpdated = newLastUpdated;
      dataYear = newDataYear;
      saveDataYear(newDataYear);
      saveLastUpdated(newLastUpdated);

      // Void Column state and selected data set when the source data changes to prevent any issues.
      localStorageService.voidColumnState();
      localStorageService.voidCurrentDataSet();

      dataSets = await csvManager.parseDataSets();
      await saveStateToLocalStorage(dataSets);
      if (dataSets.isEmpty) {
        throw Exception("Could not load datasets or retrieve them from your device's storage.");
      }
    } catch (error) {
      if (kDebugMode) {
        print(error.toString());
      }
    }
  }

  Future<String?> retrieveDataYear() async {
    return localStorageService.retrieveDataYear();
  }

  Future<String?> retrieveLastUpdated() {
    return localStorageService.retrieveLastUpdated();
  }

  Future<void> saveDataYear(String dataYear) async {
    localStorageService.storeDataYear(dataYear);
  }

  Future<void> saveLastUpdated(String lastUpdated) async {
    localStorageService.storeLastUpdated(lastUpdated);
  }

  Future<List<DataSet>?> retrieveStateFromLocalStorage() async {
    final serializedState = await localStorageService.retrieveData();
    if (serializedState != null) {
      List<dynamic> rawData = jsonDecode(serializedState);
      List<DataSet> deserializedData = [];

      for (final set in rawData) {
        DataSet finalSet = DataSet.fromJson(jsonDecode(set) as Map<String, dynamic>);
        deserializedData.add(finalSet);
      }
      return deserializedData;
    }
    return null;
  }

  Future<void> saveStateToLocalStorage(List<DataSet> appState) async {
    List<String> toConvert = [];

    for (DataSet d in appState) {
      final serializedSet = jsonEncode(d.toJson());
      toConvert.add(serializedSet);
    }

    final serializedData = jsonEncode(toConvert);
    await localStorageService.storeData(serializedData);
  }

  static void debugPrint(List<DataSet> data) {
    if (kDebugMode) {
      for (DataSet d in data) {
        print('DataSet ${d.order} - ${d.name}');
        print('Traits:');
        for (Trait trait in d.traits) {
          print('${trait.order} ${trait.name} ${trait.columnVisibility}');
        }
        print('Observations:');
        for (Observation observation in d.observations) {
          print('${observation.order} ${observation.traitOrdersAndValues}');
        }
        print('\n');
      }
    }
  }
}