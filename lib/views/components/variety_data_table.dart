import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../utilities/ui_config.dart';

class VarietyDataTable extends StatelessWidget {
  const VarietyDataTable({super.key});

  @override
  Widget build(BuildContext context) {
    return DataTable2(
        columnSpacing: 8,
        fixedColumnsColor: Colors.grey.withOpacity(0.3),
        dataRowHeight: 38.0,
        horizontalMargin: 8,
        fixedLeftColumns: 1,
        fixedTopRows: 1,
        minWidth: 3000,
        headingRowDecoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: UIConfig.dividerGrey))),
        dividerThickness: 1,
        empty: const Text("No variety data was found."),
        dataRowColor: MaterialStateProperty.resolveWith<Color?>((
            Set<MaterialState> states) => UIConfig.secondaryGrey),
        columns: _generateColumns(context),
        rows: _generateRows(context)
    );
  }

  List<DataColumn2> _generateColumns(BuildContext context) {
    return List<DataColumn2>.generate(
      context.watch<AppState>().visibleDataSet.traits.length, (index) =>
        DataColumn2(
          label: Center(
            child: Text(context.watch<AppState>().visibleDataSet.traits[index].name ?? "",
              style: Theme.of(context).textTheme.bodyLarge,
              softWrap: true,
              textAlign: TextAlign.right,
            ),
          ),
          fixedWidth: calculateColumnWidth(context.watch<AppState>().visibleDataSet.traits[index].name.length ?? 0),
        ),
    );
  }

  List<DataRow> _generateRows(BuildContext context) {
    return List<DataRow2>.generate(context.watch<AppState>().visibleDataSet.observations.length, (rowIndex) =>
        DataRow2(
          color: MaterialStateProperty.resolveWith<Color?>((
              Set<MaterialState> states) {
            if (!rowIndex.isEven) {
              return UIConfig.secondaryGrey;
            }
            return null;
          }),
          cells: _generateCells(context, rowIndex)
        )
    );
  }

  List<DataCell> _generateCells(BuildContext context, int rowIndex) {
    return List<DataCell>.generate(context
        .watch<AppState>()
        .visibleDataSet
        .observations[rowIndex].traitOrdersAndValues.length, (
        cellIndex) =>
        DataCell(
            Center(
              child: Text(
                '${context
                    .watch<AppState>()
                    .visibleDataSet
                    .observations[rowIndex]
                    .traitOrdersAndValues[cellIndex] ?? ""}',
                style: Theme
                    .of(context)
                    .textTheme
                    .bodyMedium,
                softWrap: true,
                textAlign: TextAlign.center,
              ),
            )
        )
    );
  }

  double calculateColumnWidth(int size) {
    if (20.0 * size > 170.0) {
      return 170.0;
    } else if (20.0 * size < 120){
      return 120.0;
    } else {
      return 20.0 * size;
    }
  }
}