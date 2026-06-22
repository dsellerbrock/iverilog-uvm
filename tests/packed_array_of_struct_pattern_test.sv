// Regression: a constant packed array of a packed struct initialized with a
// nested assignment pattern, e.g. (OpenTitan spi_host racl ranges)
//   localparam racl_range_t [0:0] R = '{ '{ base:.., limit:.., ps:.., en:.. } };
// This was rejected with "Packed array assignment pattern expects 66 element(s)"
// because PEAssignPattern flattened the struct element into the packed
// dimension list (netparray_t::slice_dimensions concatenates the element's
// slice dims), so the inner named struct pattern was counted against the
// struct's bit width. The constant case now folds each struct element to a flat
// NetEConst and concatenates them into the packed-array bit value.
package rp;
  typedef struct packed { logic [31:0] base; logic [31:0] limit; logic ps; logic en; } r4_t;
  typedef struct packed { logic [7:0] a; logic [7:0] b; } r2_t;
endpackage
module top;
  import rp::*;
  // single element [0:0] (the spi_host form)
  localparam r4_t [0:0] R1 = '{ '{ base:32'hAAAAAAAA, limit:32'h55555555, ps:1'b1, en:1'b1 } };
  // multi element [1:0]
  localparam r2_t [1:0] R2 = '{ '{ a:8'h11, b:8'h22 }, '{ a:8'h33, b:8'h44 } };
  logic [65:0] f1;
  logic [31:0] f2;
  int errors = 0;
  initial begin
    f1 = R1;                       // {AAAAAAAA,55555555,1,1} = 0xAAAAAAAA55555555<<2 | 3
    f2 = R2;                       // {11,22, 33,44}
    if (f1 !== 66'h2AAAAAAA955555557) errors++;
    if (f2 !== 32'h11223344)          errors++;
    if (errors == 0) $display("PASS");
    else $display("FAIL (%0d) f1=%h f2=%h", errors, f1, f2);
  end
endmodule
