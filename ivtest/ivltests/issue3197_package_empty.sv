package p;
  ;
  parameter integer value = 42;
  ; ;
endpackage

package empty_items;
  ; ;
endpackage

module top;
  initial begin
    if (p::value != 42) $fatal(1, "package declaration changed");
    $display("PASS");
  end
endmodule
