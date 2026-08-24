// A nested struct type does not make signal-backed fixed-array queue storage
// viable: each fixed member word still needs an independent runtime queue.
typedef struct {
  int values[2][$];
} signal_struct_fixed_array_container_t;

module sv_signal_struct_fixed_array_container_fail;
  signal_struct_fixed_array_container_t holder;

  initial
    holder.values[0].push_back(1);
endmodule
