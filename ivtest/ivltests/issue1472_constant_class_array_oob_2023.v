class issue1472_object_t; endclass

module issue1472_constant_class_array_oob;
  issue1472_object_t objects[0:0];
  issue1472_object_t missing;
  integer index;

  initial begin
    missing = objects[9];
    if (missing !== null) $fatal(1, "constant out-of-range class read");

    index = 9;
    missing = objects[index];
    if (missing !== null) $fatal(1, "variable out-of-range class read");

    $display("PASS");
  end
endmodule
