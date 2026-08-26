// A constructor-bound endpoint must not hide a genuinely unresolved name.
module top;
  covergroup cg(int limit) with function sample(int value);
    cp: coverpoint value {
      bins valid = {[0:limit-1]};
      bins unresolved = {[0:missing_bound]};
      bins unsupported_sibling = {[0:limit + $countones(3)]};
      bins unsupported_nested = {[0:limit ** 2]};
      bins unsupported_cast = {[0:int'(limit)]};
      bins unsupported_concat = {[0:{limit}]};
      bins unsupported_fill_sibling = {[0:limit], '1};
      bins unsupported_fill_nested = {[0:limit & '1]};
      bins unsupported_folded_width = {[0:limit + (8'hff + 8'h1)]};
      bins unsupported_select = {[0:limit[2:0]]};
      bins unsupported_with = {[0:limit]} with (item < limit);
    }
    other_cp: coverpoint value { bins zero = {0}; }
    unsupported_cross: cross cp, other_cp;
  endgroup

  covergroup cg_wide(logic [64:0] limit) with function sample(logic [64:0] value);
    cp: coverpoint value {
      bins unsupported_width = {[limit:limit]};
    }
  endgroup

  covergroup cg_ctor_set(int values[$]) with function sample(int value);
    cp: coverpoint value {
      bins unsupported_ctor_set[] = values;
    }
  endgroup

  cg bad;
  cg_wide wide_bad;
  cg_ctor_set ctor_set_bad;

  initial begin
    bad = new(4);
    wide_bad = new(65'h1_0000_0000_0000_0000);
    $display("PASSED");
  end
endmodule
