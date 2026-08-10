// Edition boundary, pre-SystemVerilog arm: iterator index querying was
// already present in IEEE 1800-2005 5.15.4, but is not Verilog-2005 syntax.
// Keep the declarations otherwise legal under IEEE 1364-2005 so the
// exact negative pins the array-method expression at the SV boundary.
module sv_edition_iter_index_old;
  integer arr[0:4];
  integer s;
  initial begin
    s = arr.sum with (item.index);
    $display("FAILED -- should not have compiled under -g2005 (got %0d)", s);
  end
endmodule
