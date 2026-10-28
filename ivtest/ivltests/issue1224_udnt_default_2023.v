module test;
  nettype logic plain_logic;
  plain_logic value;
  initial begin
    if (value !== 1'bx)
      $fatal(1, "unresolved user-nettype default was %b", value);
    $display("PASS");
  end
endmodule
