typedef logic [7:0] byte_t;
typedef struct packed { logic [3:0] hi; logic [3:0] lo; } ps_t;
typedef union packed { logic [7:0] x; byte_t y; } pu_t;
typedef enum logic [1:0] { R, G, B } col_t;

module top;
  ps_t ps;
  pu_t pu;
  col_t c;
  initial begin
    #1;
    $probe_issue2945;
    $finish;
  end
endmodule
