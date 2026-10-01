// Out-of-range unsigned indices and reversed packed part-selects must not
// constrain a different in-range element (IEEE 1800-2017/2023 7.4, 18.3).
typedef struct packed {
  logic [-1:-2][7:0] neg;
  logic [3:2][7:0] desc;
  logic [2:3][7:0] asc;
} packed_t;

class unsigned_oob;
  rand packed_t p;
  constraint k { p.neg[64'hffffffffffffffff] == 8'h12; }
endclass
class descending_reverse;
  rand packed_t p;
  constraint k { p.desc[2:3] == 16'h1234; }
endclass
class ascending_reverse;
  rand packed_t p;
  constraint k { p.asc[3:2] == 16'h5678; }
endclass
class simple_reverse;
  rand logic [1:0] v;
  constraint k { v[0:1] == 2'b01; }
endclass
class simple_unsigned_oob;
  rand logic [1:0] v;
  constraint k { v[64'hffffffffffffffff] == 1'b1; }
endclass
class foreach_index_reverse;
  rand logic [1:0] a[2];
  constraint k { foreach (a[i]) i[0:1] == 2'b01; }
endclass
module test;
  initial begin
    unsigned_oob u;
    descending_reverse d;
    ascending_reverse a;
    simple_reverse s;
    simple_unsigned_oob h;
    foreach_index_reverse f;
    u = new; d = new; a = new; s = new; h = new; f = new;
    if (u.randomize()) $fatal(1, "unsigned MAX aliased signed -1");
    if (d.randomize()) $fatal(1, "descending part endpoints were reordered");
    if (a.randomize()) $fatal(1, "ascending part endpoints were reordered");
    if (s.randomize()) $fatal(1, "simple packed part endpoints were reversed");
    if (h.randomize()) $fatal(1, "simple unsigned MAX selected a packed bit");
    if (f.randomize()) $fatal(1, "foreach index part was reversed");
    $display("PASSED");
  end
endmodule
