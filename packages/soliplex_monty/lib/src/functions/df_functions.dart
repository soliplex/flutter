import 'package:soliplex_monty/soliplex_monty.dart' show DataFrame;
import 'package:soliplex_monty/src/bridge/host_function.dart';
import 'package:soliplex_monty/src/bridge/host_function_schema.dart';
import 'package:soliplex_monty/src/bridge/host_param.dart';
import 'package:soliplex_monty/src/bridge/host_param_type.dart';
import 'package:soliplex_monty/src/data/data_frame.dart' show DataFrame;
import 'package:soliplex_monty/src/data/df_registry.dart';

/// Builds all 44 df_* host functions backed by [registry].
///
/// Each function has a [HostFunctionSchema] with typed parameters and a
/// handler closure that delegates to [DfRegistry] / [DataFrame] methods.
List<HostFunction> buildDfFunctions(DfRegistry registry) => [
      // ── Create (3) ──────────────────────────────────────────────────

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_create',
          description: 'Create a DataFrame from a list of row maps '
              'or list of lists with column names.',
          params: [
            HostParam(
              name: 'data',
              type: HostParamType.list,
              description: 'Row data',
            ),
            HostParam(
              name: 'columns',
              type: HostParamType.list,
              isRequired: false,
              description: 'Column names (for list-of-lists)',
            ),
          ],
        ),
        handler: (args) async => registry.create(
          args['data'],
          _castStringList(args['columns']),
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_from_csv',
          description: 'Create a DataFrame from a CSV string.',
          params: [
            HostParam(
              name: 'csv',
              type: HostParamType.string,
              description: 'CSV text',
            ),
            HostParam(
              name: 'delimiter',
              type: HostParamType.string,
              isRequired: false,
              defaultValue: ',',
              description: 'Column delimiter',
            ),
          ],
        ),
        handler: (args) async => registry.fromCsv(
          args['csv']! as String,
          args['delimiter'] as String? ?? ',',
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_from_json',
          description: 'Create a DataFrame from a JSON array of objects.',
          params: [
            HostParam(
              name: 'json',
              type: HostParamType.string,
              description: 'JSON string',
            ),
          ],
        ),
        handler: (args) async => registry.fromJson(args['json']! as String),
      ),

      // ── Inspect (9) ─────────────────────────────────────────────────

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_shape',
          description: 'Return [rows, columns] shape of a DataFrame.',
          params: [_handleParam],
        ),
        handler: (args) async {
          final df = registry.get(_handle(args));
          return [df.length, df.columnCount];
        },
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_columns',
          description: 'Return column names of a DataFrame.',
          params: [_handleParam],
        ),
        handler: (args) async => registry.get(_handle(args)).columns,
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_head',
          description: 'Return first n rows (default 5).',
          params: [
            _handleParam,
            HostParam(
              name: 'n',
              type: HostParamType.number,
              isRequired: false,
              defaultValue: 5,
              description: 'Number of rows',
            ),
          ],
        ),
        handler: (args) async =>
            registry.get(_handle(args)).head(_intOr(args['n'], 5)).rows,
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_tail',
          description: 'Return last n rows (default 5).',
          params: [
            _handleParam,
            HostParam(
              name: 'n',
              type: HostParamType.number,
              isRequired: false,
              defaultValue: 5,
              description: 'Number of rows',
            ),
          ],
        ),
        handler: (args) async =>
            registry.get(_handle(args)).tail(_intOr(args['n'], 5)).rows,
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_describe',
          description: 'Return count, mean, std, min, max for numeric columns.',
          params: [_handleParam],
        ),
        handler: (args) async => registry.get(_handle(args)).describe(),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_to_csv',
          description: 'Export DataFrame to CSV string.',
          params: [_handleParam],
        ),
        handler: (args) async => registry.get(_handle(args)).toCsv(),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_to_json',
          description: 'Export DataFrame to JSON string.',
          params: [_handleParam],
        ),
        handler: (args) async => registry.get(_handle(args)).toJson(),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_to_list',
          description: 'Return all rows as list of maps.',
          params: [_handleParam],
        ),
        handler: (args) async => registry.get(_handle(args)).rows,
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_column_values',
          description: 'Return all values for a single column.',
          params: [
            _handleParam,
            HostParam(
              name: 'column',
              type: HostParamType.string,
              description: 'Column name',
            ),
          ],
        ),
        handler: (args) async =>
            registry.get(_handle(args)).columnValues(args['column']! as String),
      ),

      // ── Transform (15) ──────────────────────────────────────────────

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_select',
          description: 'Select specific columns, return new handle.',
          params: [
            _handleParam,
            HostParam(
              name: 'columns',
              type: HostParamType.list,
              description: 'Column names to select',
            ),
          ],
        ),
        handler: (args) async => registry.register(
          registry.get(_handle(args)).select(_castStringList(args['columns'])!),
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_filter',
          description: 'Filter rows where column op value, return new handle.',
          params: [
            _handleParam,
            HostParam(
              name: 'column',
              type: HostParamType.string,
              description: 'Column name',
            ),
            HostParam(
              name: 'op',
              type: HostParamType.string,
              description:
                  'Comparison operator (==, !=, >, >=, <, <=, contains)',
            ),
            HostParam(
              name: 'value',
              type: HostParamType.any,
              isRequired: false,
              description: 'Value to compare (string, number, or bool)',
            ),
          ],
        ),
        handler: (args) async => registry.register(
          registry.get(_handle(args)).filter(
                args['column']! as String,
                args['op']! as String,
                args['value'],
              ),
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_sort',
          description: 'Sort by column, return new handle.',
          params: [
            _handleParam,
            HostParam(
              name: 'column',
              type: HostParamType.string,
              description: 'Column to sort by',
            ),
            HostParam(
              name: 'ascending',
              type: HostParamType.boolean,
              isRequired: false,
              defaultValue: true,
              description: 'Sort ascending (default true)',
            ),
          ],
        ),
        handler: (args) async => registry.register(
          registry.get(_handle(args)).sort(
                args['column']! as String,
                ascending: args['ascending'] as bool? ?? true,
              ),
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_group_agg',
          description: 'Group by columns and aggregate, return new handle.',
          params: [
            _handleParam,
            HostParam(
              name: 'group_cols',
              type: HostParamType.list,
              description: 'Columns to group by',
            ),
            HostParam(
              name: 'agg_map',
              type: HostParamType.map,
              description:
                  'Map of column → agg function (sum, mean, min, max, count)',
            ),
          ],
        ),
        handler: (args) async => registry.register(
          registry.get(_handle(args)).groupAgg(
                _castStringList(args['group_cols'])!,
                Map<String, String>.from(
                  args['agg_map']! as Map<String, Object?>,
                ),
              ),
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_add_column',
          description: 'Add a column with values, return new handle.',
          params: [
            _handleParam,
            HostParam(
              name: 'name',
              type: HostParamType.string,
              description: 'New column name',
            ),
            HostParam(
              name: 'values',
              type: HostParamType.list,
              description: 'Column values',
            ),
          ],
        ),
        handler: (args) async => registry.register(
          registry.get(_handle(args)).addColumn(
                args['name']! as String,
                (args['values']! as List<Object?>).cast<Object?>(),
              ),
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_drop',
          description: 'Drop columns, return new handle.',
          params: [
            _handleParam,
            HostParam(
              name: 'columns',
              type: HostParamType.list,
              description: 'Column names to drop',
            ),
          ],
        ),
        handler: (args) async => registry.register(
          registry.get(_handle(args)).drop(_castStringList(args['columns'])!),
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_rename',
          description: 'Rename columns, return new handle.',
          params: [
            _handleParam,
            HostParam(
              name: 'mapping',
              type: HostParamType.map,
              description: 'Map of old name → new name',
            ),
          ],
        ),
        handler: (args) async => registry.register(
          registry.get(_handle(args)).rename(
                Map<String, String>.from(
                  args['mapping']! as Map<String, Object?>,
                ),
              ),
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_merge',
          description: 'Merge two DataFrames on columns, return new handle.',
          params: [
            _handleParam,
            HostParam(
              name: 'other_handle',
              type: HostParamType.number,
              description: 'Handle of other DataFrame',
            ),
            HostParam(
              name: 'on',
              type: HostParamType.list,
              description: 'Join column names',
            ),
            HostParam(
              name: 'how',
              type: HostParamType.string,
              isRequired: false,
              defaultValue: 'inner',
              description: 'Join type: inner or left',
            ),
          ],
        ),
        handler: (args) async => registry.register(
          registry.get(_handle(args)).merge(
                registry.get((args['other_handle']! as num).toInt()),
                _castStringList(args['on'])!,
                how: args['how'] as String? ?? 'inner',
              ),
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_concat',
          description: 'Concatenate DataFrames, return new handle.',
          params: [
            HostParam(
              name: 'handles',
              type: HostParamType.list,
              description: 'List of DataFrame handles to concatenate',
            ),
          ],
        ),
        handler: (args) async {
          final handles = (args['handles']! as List<Object?>)
              .cast<num>()
              .map((h) => registry.get(h.toInt()))
              .toList();
          final first = handles.first;
          return registry.register(first.concat(handles.skip(1).toList()));
        },
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_fillna',
          description: 'Fill null values, return new handle.',
          params: [
            _handleParam,
            HostParam(
              name: 'value',
              type: HostParamType.any,
              isRequired: false,
              description: 'Replacement value',
            ),
          ],
        ),
        handler: (args) async => registry.register(
          registry.get(_handle(args)).fillna(args['value']),
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_dropna',
          description: 'Drop rows with null values, return new handle.',
          params: [_handleParam],
        ),
        handler: (args) async =>
            registry.register(registry.get(_handle(args)).dropna()),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_transpose',
          description: 'Transpose DataFrame, return new handle.',
          params: [_handleParam],
        ),
        handler: (args) async =>
            registry.register(registry.get(_handle(args)).transpose()),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_sample',
          description: 'Random sample of n rows, return new handle.',
          params: [
            _handleParam,
            HostParam(
              name: 'n',
              type: HostParamType.number,
              description: 'Number of rows to sample',
            ),
          ],
        ),
        handler: (args) async => registry.register(
          registry.get(_handle(args)).sample((args['n']! as num).toInt()),
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_nlargest',
          description: 'Largest n rows by column, return new handle.',
          params: [
            _handleParam,
            HostParam(
              name: 'n',
              type: HostParamType.number,
              description: 'Number of rows',
            ),
            HostParam(
              name: 'column',
              type: HostParamType.string,
              description: 'Column to sort by',
            ),
          ],
        ),
        handler: (args) async => registry.register(
          registry.get(_handle(args)).nlargest(
                (args['n']! as num).toInt(),
                args['column']! as String,
              ),
        ),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_nsmallest',
          description: 'Smallest n rows by column, return new handle.',
          params: [
            _handleParam,
            HostParam(
              name: 'n',
              type: HostParamType.number,
              description: 'Number of rows',
            ),
            HostParam(
              name: 'column',
              type: HostParamType.string,
              description: 'Column to sort by',
            ),
          ],
        ),
        handler: (args) async => registry.register(
          registry.get(_handle(args)).nsmallest(
                (args['n']! as num).toInt(),
                args['column']! as String,
              ),
        ),
      ),

      // ── Aggregate (8) ───────────────────────────────────────────────

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_mean',
          description: 'Mean of a column (or all numeric columns).',
          params: [
            _handleParam,
            HostParam(
              name: 'column',
              type: HostParamType.string,
              isRequired: false,
              description: 'Column name (omit for all)',
            ),
          ],
        ),
        handler: (args) async =>
            registry.get(_handle(args)).computeMean(args['column'] as String?),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_sum',
          description: 'Sum of a column (or all numeric columns).',
          params: [
            _handleParam,
            HostParam(
              name: 'column',
              type: HostParamType.string,
              isRequired: false,
              description: 'Column name (omit for all)',
            ),
          ],
        ),
        handler: (args) async =>
            registry.get(_handle(args)).computeSum(args['column'] as String?),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_min',
          description: 'Min of a column (or all numeric columns).',
          params: [
            _handleParam,
            HostParam(
              name: 'column',
              type: HostParamType.string,
              isRequired: false,
              description: 'Column name (omit for all)',
            ),
          ],
        ),
        handler: (args) async =>
            registry.get(_handle(args)).computeMin(args['column'] as String?),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_max',
          description: 'Max of a column (or all numeric columns).',
          params: [
            _handleParam,
            HostParam(
              name: 'column',
              type: HostParamType.string,
              isRequired: false,
              description: 'Column name (omit for all)',
            ),
          ],
        ),
        handler: (args) async =>
            registry.get(_handle(args)).computeMax(args['column'] as String?),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_std',
          description:
              'Standard deviation of a column (or all numeric columns).',
          params: [
            _handleParam,
            HostParam(
              name: 'column',
              type: HostParamType.string,
              isRequired: false,
              description: 'Column name (omit for all)',
            ),
          ],
        ),
        handler: (args) async =>
            registry.get(_handle(args)).computeStd(args['column'] as String?),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_corr',
          description:
              'Correlation matrix for numeric columns, return new handle.',
          params: [_handleParam],
        ),
        handler: (args) async =>
            registry.register(registry.get(_handle(args)).corr()),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_unique',
          description: 'Unique values in a column.',
          params: [
            _handleParam,
            HostParam(
              name: 'column',
              type: HostParamType.string,
              description: 'Column name',
            ),
          ],
        ),
        handler: (args) async =>
            registry.get(_handle(args)).unique(args['column']! as String),
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_value_counts',
          description: 'Value counts for a column.',
          params: [
            _handleParam,
            HostParam(
              name: 'column',
              type: HostParamType.string,
              description: 'Column name',
            ),
          ],
        ),
        handler: (args) async =>
            registry.get(_handle(args)).valueCounts(args['column']! as String),
      ),

      // ── Lifecycle (2) ───────────────────────────────────────────────

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_dispose',
          description: 'Dispose a single DataFrame handle.',
          params: [_handleParam],
        ),
        handler: (args) async {
          registry.dispose(_handle(args));
          return null;
        },
      ),

      HostFunction(
        schema: const HostFunctionSchema(
          name: 'df_dispose_all',
          description: 'Dispose all DataFrame handles.',
        ),
        handler: (args) async {
          registry.disposeAll();
          return null;
        },
      ),
    ];

// ── Shared helpers ────────────────────────────────────────────────────

/// Common parameter for DataFrame handle.
const _handleParam = HostParam(
  name: 'handle',
  type: HostParamType.number,
  description: 'DataFrame handle ID',
);

/// Extract handle as int from args map.
int _handle(Map<String, Object?> args) => (args['handle']! as num).toInt();

/// Convert a nullable num to int with a default.
int _intOr(Object? v, int defaultValue) =>
    v != null ? (v as num).toInt() : defaultValue;

/// Cast a nullable [Object] to `List<String>` for column-name args.
List<String>? _castStringList(Object? v) {
  if (v == null) return null;
  return (v as List<Object?>).cast<String>();
}
