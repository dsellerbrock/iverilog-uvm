// Issue #2948: variables expose their built-in VPI typespec handles.
module top;
  typedef logic [7:0] byte_t;
  typedef struct packed { logic [3:0] hi; logic [3:0] lo; } ps_t;
  typedef struct { int a; logic [3:0] b; } us_t;
  typedef union packed { logic [7:0] x; byte_t y; } pu_t;
  typedef enum logic [1:0] { R, G, B } col_t;

  logic [7:0] v; byte_t bt; logic signed [0:7] sv;
  int i; real r; string s;
  ps_t ps; us_t us; pu_t pu; col_t c;

  initial begin
    #1 $probe_typespec;
    $display("DONE");
  end
endmodule
