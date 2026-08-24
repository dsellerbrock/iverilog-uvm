// Signal-backed fixed arrays of queues need one runtime container per fixed
// word. Until that backend exists, reject this declaration before lowering.
module sv_signal_fixed_array_container_fail;
  int values[2][$];

  initial
    values[0].push_back(1);
endmodule
