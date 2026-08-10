// User-visible same-object reentrancy through pre_randomize is sequential:
// the nested call completes before the outer runtime solve frame begins.
// Each successful call must therefore contribute its own randc value.
class randc_txn_reentrant_item;
  randc bit [1:0] value;
  bit in_hook;
  bit [1:0] nested_value;

  function void pre_randomize();
    int status;
    if (!in_hook) begin
      in_hook = 1;
      status = this.randomize();
      if (status !== 1)
        $fatal(1, "nested randomize failed");
      nested_value = value;
      in_hook = 0;
    end
  endfunction
endclass

module test;
  initial begin
    randc_txn_reentrant_item item;
    bit [3:0] seen;

    item = new;
    item.srandom(32'h7182_93a4);
    for (int cycle = 0; cycle < 8; cycle++) begin
      seen = '0;
      for (int call = 0; call < 2; call++) begin
        if (item.randomize() !== 1)
          $fatal(1, "outer randomize failed");
        if (seen[item.nested_value])
          $fatal(1, "nested call did not commit its own randc value");
        seen[item.nested_value] = 1'b1;
        if (seen[item.value])
          $fatal(1, "outer call repeated the nested randc value");
        seen[item.value] = 1'b1;
      end
      if (seen !== 4'b1111)
        $fatal(1, "two reentrant outer calls did not complete one cycle");
    end

    $display("PASSED");
  end
endmodule
