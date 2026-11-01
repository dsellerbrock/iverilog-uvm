module main;
  logic signed [7:0] value = 8'b000x0001;
  logic signed [7:0] zvalue = 8'b000z0001;
  logic [7:0] unsigned_value = 8'b000x0001;

  initial begin
    $display("x=%b %b %b z=%b %b %b",
             +value, ~value, value << 1,
             +zvalue, ~zvalue, zvalue << 1);
    if ((+value) !== 8'hxx || (~value) !== 8'hxx || (value << 1) !== 8'hxx)
      $fatal(1, "every nonlogical result must be all X");
    if ((+zvalue) !== 8'hxx || (~zvalue) !== 8'hxx || (zvalue << 1) !== 8'hxx)
      $fatal(1, "a signed Z operand must make each nonlogical result all X");
    if ((+unsigned_value) !== 8'b000x0001
        || (~unsigned_value) !== 8'b111x1110
        || (unsigned_value << 1) !== 8'b00x00010
        || (!value) !== 1'b0)
      $fatal(1, "unsigned X or logical operation changed behavior");
    $display("PASSED");
  end
endmodule
