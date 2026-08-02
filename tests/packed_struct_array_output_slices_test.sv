package packed_struct_array_output_slices_pkg;
  typedef enum logic [2:0] {Idle = 3'h0, Active = 3'h5} state_t;
  typedef struct packed {
    logic [1:0][3:0] count;
    state_t [1:0] state;
  } wrap_t;
endpackage

module packed_struct_array_output_slices_child #(
  parameter int INDEX = 0
) (
  output logic [3:0] count_o,
  output packed_struct_array_output_slices_pkg::state_t state_o
);
  import packed_struct_array_output_slices_pkg::*;
  assign count_o = INDEX ? 4'ha : 4'h3;
  assign state_o = INDEX ? Active : Idle;
endmodule

module packed_struct_array_output_slices_test;
  import packed_struct_array_output_slices_pkg::*;
  wrap_t value;
  for (genvar k = 0; k < 2; k++) begin : gen_outputs
    packed_struct_array_output_slices_child #(.INDEX(k)) child (
      .count_o(value.count[k]),
      .state_o(value.state[k])
    );
  end
  initial begin
    #1;
    if (value.count[0] !== 4'h3 || value.count[1] !== 4'ha ||
        value.state[0] !== Idle || value.state[1] !== Active)
      $fatal(1, "packed-struct array output slices failed");
    $display("PASS: packed-struct array output slices");
  end
endmodule
