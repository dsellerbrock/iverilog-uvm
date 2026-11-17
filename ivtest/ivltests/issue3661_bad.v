class C;
  rand logic [3:0] down;
  rand logic [0:3] up;
  constraint bad_down { down[0:3] == 1; }
  constraint bad_up { up[3:0] == 1; }
  constraint bad_outside { down[-1:4] == 1; }
endclass
module top;
  C c;
  more_top extra();
  initial c = new;
endmodule
typedef struct packed {
  logic [3:2][7:0] desc;
  logic [2:3][7:0] asc;
} packed_t;
class More;
  rand packed_t p;
  rand logic [1:0] a[2];
  constraint bad_desc { p.desc[2:3] == 16'h1234; }
  constraint bad_asc { p.asc[3:2] == 16'h5678; }
  constraint bad_foreach { foreach (a[i]) i[0:1] == 2'b01; }
endclass
module more_top;
  More m;
  initial m = new;
endmodule
