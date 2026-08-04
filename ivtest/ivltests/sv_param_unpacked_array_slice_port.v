package sv_param_unpacked_array_slice_port_pkg;
  localparam logic [7:0] Desc [3:0] = '{8'h30, 8'h20, 8'h10, 8'h00};
  localparam logic [7:0] Asc  [0:3] = '{8'ha0, 8'ha1, 8'ha2, 8'ha3};
endpackage

module sv_param_uarray_four_asc(
  input  logic [7:0] value_i [0:3],
  output logic [31:0] value_o
);
  assign value_o = {value_i[0], value_i[1], value_i[2], value_i[3]};
endmodule

module sv_param_uarray_four_desc(
  input  logic [7:0] value_i [3:0],
  output logic [31:0] value_o
);
  assign value_o = {value_i[3], value_i[2], value_i[1], value_i[0]};
endmodule

module sv_param_uarray_two_asc(
  input  logic [7:0] value_i [0:1],
  output logic [15:0] value_o
);
  assign value_o = {value_i[0], value_i[1]};
endmodule

module sv_param_uarray_two_desc(
  input  logic [7:0] value_i [1:0],
  output logic [15:0] value_o
);
  assign value_o = {value_i[1], value_i[0]};
endmodule

module sv_param_unpacked_array_slice_port;
  import sv_param_unpacked_array_slice_port_pkg::*;

  logic [31:0] desc_to_asc, desc_to_desc;
  logic [31:0] asc_to_asc, asc_to_desc;
  logic [15:0] desc_slice_to_asc, asc_slice_to_desc;
  integer errors = 0;

  sv_param_uarray_four_asc  u_desc_to_asc  (.value_i(Desc), .value_o(desc_to_asc));
  sv_param_uarray_four_desc u_desc_to_desc (.value_i(Desc), .value_o(desc_to_desc));
  sv_param_uarray_four_asc  u_asc_to_asc   (.value_i(Asc),  .value_o(asc_to_asc));
  sv_param_uarray_four_desc u_asc_to_desc  (.value_i(Asc),  .value_o(asc_to_desc));

`ifndef OMIT_ARRAY_SLICES
  sv_param_uarray_two_asc u_desc_slice_to_asc (
    .value_i(Desc[2:1]),
    .value_o(desc_slice_to_asc)
  );
  sv_param_uarray_two_desc u_asc_slice_to_desc (
    .value_i(Asc[1:2]),
    .value_o(asc_slice_to_desc)
  );
`endif

  task automatic check(input logic [31:0] got,
                       input logic [31:0] expected,
                       input string what);
    if (got !== expected) begin
      $display("FAILED %s: got %h expected %h", what, got, expected);
      errors++;
    end
  endtask

  initial begin
    #1;
    check(desc_to_asc,       32'h30201000, "Desc -> [0:3]");
    check(desc_to_desc,      32'h30201000, "Desc -> [3:0]");
    check(asc_to_asc,        32'ha0a1a2a3, "Asc -> [0:3]");
    check(asc_to_desc,       32'ha0a1a2a3, "Asc -> [3:0]");
`ifndef OMIT_ARRAY_SLICES
    check(desc_slice_to_asc, 16'h2010,     "Desc[2:1] -> [0:1]");
    check(asc_slice_to_desc, 16'ha1a2,     "Asc[1:2] -> [1:0]");
`endif
    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED -- %0d mismatch(es)", errors);
    $finish;
  end
endmodule
