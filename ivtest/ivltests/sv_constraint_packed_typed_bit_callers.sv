// Foreach indices are signed four-state int values; packed structs preserve
// their logic/bit classification through iterator and local constraints.
typedef struct packed { logic [1:0] v; } logic_word_t;
typedef struct packed { bit [1:0] v; } bit_word_t;
class fixed_foreach_index;
  rand logic [1:0] a[1];
  rand bit [5:0] idx;
  constraint k { foreach (a[i]) i[idx] == 1'b0; }
endclass
class dynamic_foreach_index;
  rand logic [1:0] a[];
  rand bit [5:0] idx;
  constraint k { a.size() == 1; foreach (a[i]) i[idx] == 1'b0; }
endclass
class logic_struct_iterator;
  rand logic_word_t a[1];
  rand bit [1:0] idx;
  constraint k { a.sum() with (item[idx]) == 1'b0; }
endclass
class bit_struct_iterator;
  rand bit_word_t a[1];
  rand bit [1:0] idx;
  constraint k { a.sum() with (item[idx]) == 1'b0; }
endclass
class bit_assoc_key;
  rand bit value;
  rand bit [5:0] idx;
  int state_map[bit [1:0]];
  constraint k { idx == 32; foreach (state_map[i]) i[idx] == 1'b0; value == 1; }
endclass
class logic_assoc_key;
  rand bit value;
  rand bit [5:0] idx;
  int state_map[logic [1:0]];
  constraint k { idx == 2; foreach (state_map[i]) i[idx] == 1'b0; value == 1; }
endclass
module test;
  initial begin
    fixed_foreach_index f;
    dynamic_foreach_index d;
    logic_struct_iterator l;
    bit_struct_iterator b;
    bit_assoc_key ab;
    logic_assoc_key al;
    logic_word_t sl;
    bit_word_t sb;
    bit [1:0] idx;
    f = new; d = new; l = new; b = new; ab = new; al = new;
    ab.state_map[2'b01] = 7;
    al.state_map[2'b01] = 7;
    if (!f.randomize() with { idx == 1; }) $fatal(1, "fixed valid");
    if (f.randomize() with { idx == 32; }) $fatal(1, "fixed oob");
    if (!d.randomize() with { idx == 1; }) $fatal(1, "dynamic valid");
    if (d.randomize() with { idx == 32; }) $fatal(1, "dynamic oob");
    if (!l.randomize() with { idx == 1; }) $fatal(1, "struct valid");
    if (l.randomize() with { idx == 2; }) $fatal(1, "struct oob");
    if (!b.randomize() with { idx == 2; }) $fatal(1, "bit struct oob zero");
    if (!std::randomize(sl, idx) with { idx == 1; sl[idx] == 1'b0; })
      $fatal(1, "local struct valid");
    if (std::randomize(sl, idx) with { idx == 2; sl[idx] == 1'b0; })
      $fatal(1, "local struct oob");
    if (!std::randomize(sb, idx) with { idx == 2; sb[idx] == 1'b0; })
      $fatal(1, "local bit struct oob zero");
    if (!ab.randomize() || ab.value != 1)
      $fatal(1, "two-state associative key OOB zero rejected");
    if (al.randomize())
      $fatal(1, "four-state associative key OOB read succeeded");
    $display("PASSED");
  end
endmodule
