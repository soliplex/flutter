/// Parameter types for host function arguments.
enum HostParamType {
  /// String parameter. Monty Python `str`.
  string,

  /// Integer parameter. Monty Python `int`.
  integer,

  /// Floating-point parameter. Monty Python `float`.
  number,

  /// Boolean parameter. Monty Python `bool`.
  boolean,

  /// List parameter. Monty Python `list`.
  list,

  /// Map/dict parameter. Monty Python `dict`.
  map;

  /// JSON Schema type name for tool protocol export.
  String get jsonSchemaType => switch (this) {
        string => 'string',
        integer => 'integer',
        number => 'number',
        boolean => 'boolean',
        list => 'array',
        map => 'object',
      };
}
