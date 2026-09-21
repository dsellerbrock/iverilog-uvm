class overflow_item;
  rand bit [63:0] value;
  constraint distribution_c {
    value dist {[64'h0000_0000_0000_0000:64'hffff_ffff_ffff_ffff] := 1};
  }
endclass

module test;
  overflow_item item;
  initial begin
    item = new;
    if (item.randomize()) $fatal(1, "unrepresentable exact cardinality succeeded");
    $display("PASSED");
  end
endmodule
