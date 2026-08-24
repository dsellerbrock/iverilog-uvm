// A specialization-cache lookup is not an elaboration attempt.  Invalid
// typed value actuals must receive exactly the ordinary bind diagnostic when
// the specialization is elaborated, not an extra diagnostic from key probing.
typedef struct {
  int value;
} cache_probe_pair_t;

class cache_probe_real #(real VALUE = 1.0);
endclass

class cache_probe_string #(string VALUE = "ok");
endclass

class cache_probe_struct #(
  cache_probe_pair_t VALUE = '{0}
);
endclass

module sv_param_class_cache_probe_diagnostic_fail;
  cache_probe_real#(missing_real) real_item;
  cache_probe_string#(missing_string) string_item;
  cache_probe_struct#(missing_struct) struct_item;
endmodule
