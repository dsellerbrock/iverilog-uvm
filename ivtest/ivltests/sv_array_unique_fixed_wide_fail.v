// Fixed-array unique materialization currently has an 8-bit width field.
// Reject wider integral elements loudly instead of truncating or treating
// an unsigned 256-bit element as the real-kind zero descriptor.
module main;
  bit [255:0] two_state_values[2];
  logic [299:0] four_state_values[2];
  bit [255:0] two_state_result[$];
  logic [299:0] four_state_result[$];
  int indexes[$];
  initial begin
    two_state_result = two_state_values.unique;
    indexes = two_state_values.unique_index;
    four_state_result = four_state_values.unique();
    indexes = four_state_values.unique_index();
  end
endmodule
