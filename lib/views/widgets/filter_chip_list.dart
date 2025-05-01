import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A widget that displays filter chips for history filtering
class FilterChipList extends StatefulWidget {
  /// Callback when date range is selected
  final Function(DateTime? start, DateTime? end) onDateRangeSelected;

  /// Callback when plant type is selected
  final Function(String?) onPlantTypeSelected;

  /// Callback when disease is selected
  final Function(String?) onDiseaseSelected;

  /// Available plant types for filtering (auto-populated if null)
  final List<String>? availablePlantTypes;

  /// Available diseases for filtering (auto-populated if null)
  final List<String>? availableDiseases;

  const FilterChipList({
    Key? key,
    required this.onDateRangeSelected,
    required this.onPlantTypeSelected,
    required this.onDiseaseSelected,
    this.availablePlantTypes,
    this.availableDiseases,
  }) : super(key: key);

  @override
  State<FilterChipList> createState() => _FilterChipListState();
}

class _FilterChipListState extends State<FilterChipList> {
  String? _selectedPlantType;
  String? _selectedDisease;
  DateTimeRange? _selectedDateRange;

  // Default plant types if none provided
  final List<String> _defaultPlantTypes = [
    'Apple',
    'Cherry',
    'Corn',
    'Grape',
    'Peach',
    'Pepper',
    'Potato',
    'Tomato',
    'Strawberry',
  ];

  // Default disease types if none provided
  final List<String> _defaultDiseases = [
    'Healthy',
    'Scab',
    'Black Rot',
    'Rust',
    'Spot',
    'Blight',
    'Mold',
    'Mildew',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Filter Results',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),

        // Date range filter
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              // Date Range Filter
              FilterChip(
                label: Text(
                  _selectedDateRange != null
                      ? '${DateFormat.MMMd().format(_selectedDateRange!.start)} - ${DateFormat.MMMd().format(_selectedDateRange!.end)}'
                      : 'Date Range',
                ),
                selected: _selectedDateRange != null,
                onSelected: (selected) async {
                  if (selected) {
                    final DateTimeRange? range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      currentDate: DateTime.now(),
                    );

                    if (range != null) {
                      setState(() {
                        _selectedDateRange = range;
                      });
                      widget.onDateRangeSelected(range.start, range.end);
                    }
                  } else {
                    setState(() {
                      _selectedDateRange = null;
                    });
                    widget.onDateRangeSelected(null, null);
                  }
                },
                avatar: Icon(
                  _selectedDateRange != null
                      ? Icons.date_range
                      : Icons.calendar_today,
                ),
              ),

              const SizedBox(width: 8),

              // Plant Type Filter
              Wrap(
                spacing: 8,
                children: [
                  for (final type
                      in widget.availablePlantTypes ?? _defaultPlantTypes)
                    FilterChip(
                      label: Text(type),
                      selected: _selectedPlantType == type,
                      onSelected: (selected) {
                        setState(() {
                          _selectedPlantType = selected ? type : null;
                        });
                        widget.onPlantTypeSelected(_selectedPlantType);
                      },
                    ),
                ],
              ),
            ],
          ),
        ),

        // Disease Filter
        if (widget.availableDiseases != null || _defaultDiseases.isNotEmpty)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Wrap(
              spacing: 8,
              children: [
                for (final disease
                    in widget.availableDiseases ?? _defaultDiseases)
                  FilterChip(
                    label: Text(disease),
                    selected: _selectedDisease == disease,
                    onSelected: (selected) {
                      setState(() {
                        _selectedDisease = selected ? disease : null;
                      });
                      widget.onDiseaseSelected(_selectedDisease);
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
