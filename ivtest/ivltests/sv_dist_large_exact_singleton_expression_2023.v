class singleton_expression_item;
  rand bit [31:0] value;
  constraint fixed_c { value == 32'd1; }
  constraint distribution_c {
    (~value) dist {'1 :/ 9, [0:('1 - 1'b1)] :/ 1};
  }
endclass

module test;
  singleton_expression_item item;
  initial begin
    item = new;
    repeat (8)
      if (!item.randomize() || item.value != 32'd1
          || ~item.value != 32'hffff_fffe)
        $fatal(1, "fixed complemented expression lost exact distribution");
    $display("PASSED");
  end
endmodule
