// Out-of-range unsigned indices must not constrain a different in-range
// element (IEEE 1800-2017/2023 7.4, 18.3).
typedef struct packed {
  logic [-1:-2][7:0] neg;
  logic [3:2][7:0] desc;
  logic [2:3][7:0] asc;
} packed_t;

class unsigned_oob;
  rand packed_t p;
  constraint k { p.neg[64'hffffffffffffffff] == 8'h12; }
endclass

class simple_unsigned_oob;
  rand logic [1:0] v;
  constraint k { v[64'hffffffffffffffff] == 1'b1; }
endclass

module test;
  initial begin
    unsigned_oob u;
    simple_unsigned_oob h;
    u = new; h = new;
    if (u.randomize()) $fatal(1, "unsigned MAX aliased signed -1");
    if (h.randomize()) $fatal(1, "simple unsigned MAX selected a packed bit");
    $display("PASSED");
  end
endmodule
