// IEEE 1800-2023 37.26: the members of a packed struct/union variable are
// reachable through vpiMember and vpi_handle_by_name.
module top;
  typedef struct packed { bit [1:0] a; logic [1:0] b; } in_t;
  typedef struct packed { logic [3:0] hi; in_t mid; logic [3:0] lo; } ps_t;
  typedef union packed { logic [7:0] w; logic [7:0] v; } pu_t;
  ps_t ps;
  pu_t pu;
  initial begin
    ps = 12'hA65; pu = 8'h3C;
    #1 $probe;
    $display("ps=%h", ps);
  end
endmodule
