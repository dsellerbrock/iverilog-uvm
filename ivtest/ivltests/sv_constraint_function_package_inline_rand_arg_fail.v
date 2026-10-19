// A package function cannot capture target rand state through an inline argument.
package constraint_function_package_inline_rand_arg_pkg;
  function automatic int identity(input int value);
    return value;
  endfunction
endpackage

class Transaction;
  rand int data;
endclass

module test;
  Transaction req;

  initial begin
    req = new();
    if (!req.randomize() with {
      req.data == constraint_function_package_inline_rand_arg_pkg::identity(this.data);
    })
      $fatal(1, "inline constraint failed");
  end
endmodule
