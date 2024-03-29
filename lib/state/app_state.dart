import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:variety_testing_app/models/observation.dart';
import 'package:variety_testing_app/state/csv_manager.dart';
import 'package:variety_testing_app/state/data_repository.dart';
import 'package:variety_testing_app/state/local_storage_service.dart';
import '../models/column_visibility.dart';
import '../models/data_set.dart';
import '../models/trait.dart';
import 'dart:collection';

class AppState extends ChangeNotifier {
  String indexUrl;
  late DataRepository dataRepository;
  List<String> dropdownValues = [];
  DataSet? _currentDataSet;
  DataSet? _visibleDataSet;
  List<TraitsFilter> _currentTraits = [];
  Map<String, List<TraitsFilter>> _columnState = { };
  bool isLoading = true;
  bool releasedToggle = false;
  String? error;

  get currentDataSet => _currentDataSet;
  get currentTraits => _currentTraits;
  get visibleDataSet => _visibleDataSet;

  AppState(this.indexUrl) {
    dataRepository = DataRepository(CSVManager(indexUrl, Client()), LocalStorageService());
    initializeData();
  }

  Future<void> initializeData() async {
    try {
      await dataRepository.initializeData();
      dropdownValues = dataRepository.dataSets.map((ds) => ds.name).toList();
      _currentDataSet = await initializeCurrentDataSet();
      await initializeTraits();
      if (_currentDataSet != null) {
        _currentTraits = _columnState[_currentDataSet!.name]!;
        _visibleDataSet = await createVisibleDataset(_currentDataSet!);
      } else {
        throw Exception("Could not initialize current data set.");
      }
      isLoading = false;
      notifyListeners();
    } catch(e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> retryDataLoad() async {
    isLoading = true;
    await initializeData();
  }

  Future<DataSet?> initializeCurrentDataSet() async {
    final serializedDataSetName = await dataRepository.localStorageService.retrieveCurrentDataSet();
    try {
      if (serializedDataSetName != null) {
          final dataSetNameFromStorage = jsonDecode(serializedDataSetName) as String;
          DataSet tempDataSet = dataRepository.dataSets.firstWhere((set) => set.name == dataSetNameFromStorage);
          return tempDataSet;
      } else {
        DataSet tempDataSet = dataRepository.dataSets.first;
        dataRepository.localStorageService.storeCurrentDataSet(jsonEncode(tempDataSet.name));
        return tempDataSet;
      }
    } catch(e) {
      error = "Could not initialize current data set.";
      notifyListeners();
    }
    return null;
  }

  Future<void> initializeTraits() async {
    // Get column state from local storage
    final serializedColumnState = await dataRepository.localStorageService.retrieveColumnState();
    // If not null try to create from it.
    if (serializedColumnState != null) {
      try {
          final columnStateFromStorage = jsonDecode(serializedColumnState) as Map<String, dynamic>;
          columnStateFromStorage.forEach((key, value) {
            List<TraitsFilter> filterState = [];
            for (final filter in value) {
              filterState.add(TraitsFilter.fromJson(filter));
            }
            _columnState[key] = filterState;
          });
      // If you cant create from it reset column state and create from scratch
      } catch(e) {
        _columnState = { };
        createColumnState();
      }
    } else {
      createColumnState();
    }
  }

  Future<void> createColumnState () async {
    for (DataSet ds in dataRepository.dataSets) {
        List<TraitsFilter> traitFilters = [];
        for (Trait trait in ds.traits) {
          if (trait.columnVisibility == ColumnVisibility.shownByDefault) {
            traitFilters.add(TraitsFilter(trait.name, true));
          } else if (trait.columnVisibility == ColumnVisibility.hiddenByDefault){
            traitFilters.add(TraitsFilter(trait.name, false));
          } 
        }
        _columnState[ds.name] = traitFilters;
      }
      dataRepository.localStorageService.storeColumnState(jsonEncode(_columnState));
  }

  Future<void> changeDataSet(String? name) async {
    try {
      DataSet dataSet = dataRepository.dataSets.firstWhere((set) =>
      set.name == name);
      _currentDataSet = dataSet;
      dataRepository.localStorageService.storeCurrentDataSet(
          jsonEncode(_currentDataSet!.name));
      _currentTraits = _columnState[currentDataSet!.name]!;
      _visibleDataSet = await createVisibleDataset(_currentDataSet!);
      notifyListeners();
    } catch(e) {
      error = e.toString();
      notifyListeners();
    }
  }

  toggleCheckbox(int index) async {
    currentTraits[index].isChecked = !currentTraits[index].isChecked;
    _visibleDataSet = await createVisibleDataset(_currentDataSet!);
    dataRepository.localStorageService.storeColumnState(jsonEncode(_columnState));
    notifyListeners();
  }

  toggleReleased() async {
    releasedToggle = !releasedToggle;
    _visibleDataSet = await createVisibleDataset(_currentDataSet!);
    notifyListeners();
  }

  // This function adjusts the data in the app to show only what we want.
  Future<DataSet> createVisibleDataset(DataSet curSet) async {
    // Create a blank dataset to show
    DataSet visibleDataSet = DataSet(order: 1, name: curSet.name, traits: [], observations: []);
    List<Trait> hiddenColumns = [];
    List<int> shownColumns = [];
    Trait? releasedTrait;
    int traitOrderHeaders = 0;
    // Loop through and add columns which are shown.
    for (int colIdx = 0; colIdx < curSet.traits.length; colIdx++) {
      Trait curColumn = curSet.traits[colIdx];

      switch (curColumn.columnVisibility) {
        // Never show Released Column
        case ColumnVisibility.releasedColumn:
          hiddenColumns.add(curColumn);
          releasedTrait = curColumn;
          break;

        case ColumnVisibility.neverShown:
          hiddenColumns.add(curColumn);
          break;

        case ColumnVisibility.alwaysShown:
          visibleDataSet.traits.add(
              Trait(
                  order: traitOrderHeaders,
                  name: curColumn.name,
                  columnVisibility: curColumn.columnVisibility)
              );

          traitOrderHeaders += 1;
          shownColumns.add(curColumn.order);
          break;

        case ColumnVisibility.shownByDefault:
          if (_currentTraits.any((element) => element.traitName == curColumn.name && element.isChecked == true)) {
            visibleDataSet.traits.add(
                Trait(
                    order: traitOrderHeaders,
                    name: curColumn.name,
                    columnVisibility: curColumn.columnVisibility
                )
            );

            traitOrderHeaders += 1;
            shownColumns.add(curColumn.order);
          } else if (_currentTraits.any((element) => element.traitName == curColumn.name && element.isChecked == false)) {
            hiddenColumns.add(curColumn);
          }
          break;

        case ColumnVisibility.hiddenByDefault:
          if (_currentTraits.any((element) => element.traitName == curColumn.name && element.isChecked == true)) {
            visibleDataSet.traits.add(
              Trait(
              order: traitOrderHeaders,
              name: curColumn.name,
              columnVisibility: curColumn.columnVisibility
              )
            );

            traitOrderHeaders += 1;
            shownColumns.add(curColumn.order);
          } else if (_currentTraits.any((element) => element.traitName == curColumn.name && element.isChecked == false)) {
            hiddenColumns.add(curColumn);
          }
          break;
      }
    }

    int orderCounter = 0;
    int traitOrder = 0;
    List<(int, String)> obTraits = [];

    // Extract traits to a list - sort by the key and then add as observations to the blank data set
    for (Observation obs in curSet.observations) {
      HashMap<int, String> updatedTraits = HashMap<int, String>();
      // Filter out released
      if (releasedToggle == true) {
        if (obs.traitOrdersAndValues[releasedTrait?.order] == "0") {
          // Skip adding this trait because it isn't released.
          continue;
        }
      }
      // Extract the keys and values - adding them to a list to be sortable
      for (int key in obs.traitOrdersAndValues.keys) {
        if (shownColumns.contains(key)) {
          obTraits.add((key, obs.traitOrdersAndValues[key]!.toString()));
        }
      }
      // Sort the Keys to match to the correct columns and re order.
      obTraits.sort((a, b) => a.$1.compareTo(b.$1));
      for (int x = 0; x < obTraits.length; x++) {
        updatedTraits[traitOrder] = obTraits[x].$2; 
        traitOrder = traitOrder + 1;
      }
      // Add the data set to the observations.
      visibleDataSet.observations.add(Observation(order: orderCounter, traitOrdersAndValues: updatedTraits));
      orderCounter = orderCounter + 1;
      traitOrder = 0;
      obTraits = [];
    }
    
    return visibleDataSet;
    }
}

// Helper class for traits Filter
class TraitsFilter {
  TraitsFilter(
      this.traitName,
      [this.isChecked = false]
      );
  String traitName;
  bool isChecked;

  TraitsFilter.fromJson(Map<String, dynamic> json)
      : traitName = json['traitName'] as String,
        isChecked = json['isChecked'] as bool;

  Map<String, dynamic> toJson() {
    return {
      'traitName': traitName, 
      'isChecked': isChecked
      };
  }
      
}
