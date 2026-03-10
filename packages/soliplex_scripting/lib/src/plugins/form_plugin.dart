import 'package:soliplex_agent/soliplex_agent.dart' show FormApi;
import 'package:soliplex_interpreter_monty/soliplex_interpreter_monty.dart';

/// Plugin exposing form creation and validation to Monty scripts.
class FormPlugin extends MontyPlugin {
  FormPlugin({required FormApi formApi}) : _formApi = formApi;

  final FormApi _formApi;

  @override
  String get namespace => 'form';

  @override
  List<HostFunction> get functions => [
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'form_create',
            description: 'Create a dynamic form with field definitions.',
            params: [
              HostParam(
                name: 'fields',
                type: HostParamType.list,
                description: 'List of field definition maps.',
              ),
            ],
          ),
          handler: (args) async {
            final raw = args['fields']! as List<Object?>;
            final fields = <Map<String, Object?>>[];
            for (final item in raw) {
              fields.add(Map<String, Object?>.from(item! as Map));
            }
            return _formApi.createForm(fields);
          },
        ),
        HostFunction(
          schema: const HostFunctionSchema(
            name: 'form_set_errors',
            description: 'Set validation errors on a form.',
            params: [
              HostParam(
                name: 'handle',
                type: HostParamType.integer,
                description: 'Form handle.',
              ),
              HostParam(
                name: 'errors',
                type: HostParamType.map,
                description: 'Map of field name to error message.',
              ),
            ],
          ),
          handler: (args) async {
            final handle = (args['handle']! as num).toInt();
            final raw = args['errors'];
            if (raw is! Map) {
              throw ArgumentError.value(raw, 'errors', 'Expected a map.');
            }
            return _formApi.setFormErrors(
              handle,
              Map<String, String>.from(raw),
            );
          },
        ),
      ];
}
