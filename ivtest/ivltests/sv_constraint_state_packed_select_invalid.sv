// IEEE 1800-2017 18.3: invalid four-state reads fail; unsupported packed
// struct state widths/types must not silently constrain a different value.
typedef struct packed { logic [3:0] bits; } logic_struct_t;
typedef struct packed { bit [64:0] bits; } wide_struct_t;
class vector_state;
  logic [3:0] mask = 4'b1010;
  bit [3:0] select_index = 7;
  rand bit pick;
  constraint c { mask[select_index] == 1'b0; pick == 1; }
endclass
class x_vector_state;
  logic [3:0] mask = 4'bx000;
  rand bit pick;
  constraint c { pick == mask[3]; }
endclass
class struct_state;
  logic_struct_t flags = 4'b1010;
  bit [3:0] select_index = 7;
  rand bit pick;
  constraint c { flags[select_index] == 1'b0; pick == 1; }
endclass
class wide_state;
  wide_struct_t flags = 65'h10000000000000000;
  rand bit pick;
  constraint c { flags[64] == 1'b1; pick == 1; }
endclass
module top;
  vector_state v;
  x_vector_state x;
  struct_state s;
  wide_state w;
  initial begin
    v = new; x = new; s = new; w = new;
    if (v.randomize()) $fatal(1, "four-state vector OOB read passed");
    if (x.randomize()) $fatal(1, "four-state X read passed");
    if (s.randomize()) $fatal(1, "four-state struct state read passed");
    if (w.randomize()) $fatal(1, "wide struct state read passed");
    $display("PASSED");
  end
endmodule
