class nonsingleton_expression_item;
  rand bit [9:0] value;
  constraint distribution_c { (~value) dist {[10'd0:10'd300] :/ 1}; }
endclass

module test;
  nonsingleton_expression_item item;
  initial begin
    item = new;
    item.value = 10'h155;
    if (item.randomize())
      $fatal(1, "unsupported non-singleton expression succeeded");
    if (item.value != 10'h155)
      $fatal(1, "failed randomize changed the object");
    $display("PASSED");
  end
endmodule
