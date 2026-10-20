// IEEE 1800-2017 18.5.12 / 1800-2023 18.5.11: caller-state functions in inline constraints.
package constraint_function_pkg;
  function automatic bit [31:0] mask(input string name);
    return name == "WO" ? 32'h0000_0001 : 32'h0000_0002;
  endfunction
endpackage

class Transaction;
  rand bit [31:0] data;
endclass

module test;
  import constraint_function_pkg::*;
  Transaction req;
  string rname;

  initial begin
    req = new();
    rname = "WO";
    if (!req.randomize() with { req.data == mask(rname); })
      $fatal(1, "first package-function constraint failed");
    if (req.data !== 32'h0000_0001)
      $fatal(1, "first mask result was %h", req.data);

    rname = "RO";
    if (!req.randomize() with { req.data == mask(rname); })
      $fatal(1, "second package-function constraint failed");
    if (req.data !== 32'h0000_0002)
      $fatal(1, "second mask result was %h", req.data);
    $display("PASSED");
  end
endmodule
