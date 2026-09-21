class singleton_unsat_item;
  rand bit [31:0] value;
  constraint first_c { value == 32'd1; }
  constraint second_c { value == 32'd2; }
  constraint distribution_c {
    (~value) dist {'1 :/ 9, [0:('1 - 1'b1)] :/ 1};
  }
endclass

module test;
  singleton_unsat_item item;
  initial begin
    item = new;
    item.value = 32'h1234_5678;
    if (item.randomize()) $fatal(1, "UNSAT singleton expression succeeded");
    if (item.value != 32'h1234_5678)
      $fatal(1, "UNSAT randomize changed the object");
    $display("PASSED");
  end
endmodule
