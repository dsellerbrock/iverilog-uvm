// IEEE 1800-2017/2023 15.5.5: an event variable is assigned another event
// or null.
module issue699_event_assign_fail;
  event e;
  int i;
  initial e = i;
endmodule
