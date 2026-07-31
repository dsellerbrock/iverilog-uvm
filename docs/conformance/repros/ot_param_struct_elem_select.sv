// Reproducer (silent wrong result): selecting an element of a packed
// array PARAMETER whose element type is a packed struct returned a zero
// of the parameter's FULL width -- no error, no warning.
//
// A and B hold the identical 128 bits. A[1] read correctly; B[1] did
// not. elaborate_expr_param_or_specparam_ asked "more than one packed
// dimension?" of netvector_t alone, and `r_t [1:0]' is a netparray_t,
// so the select fell through to the single-dimension path.
module top;
  typedef struct packed { logic [31:0] base; logic [31:0] limit; } r_t;
  localparam logic [1:0][63:0] A = 128'h00000001_00000002_00000003_00000004;
  localparam r_t [1:0]         B = 128'h00000001_00000002_00000003_00000004;
  initial begin
    $display("A[1] = %h  (expect 0000000100000002)", A[1]);
    $display("B[1] = %h  (expect 0000000100000002)", B[1]);
  end
endmodule
