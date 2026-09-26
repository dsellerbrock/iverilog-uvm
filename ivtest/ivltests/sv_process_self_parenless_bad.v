// An unknown member of the built-in process class stays a loud error.
module test;
  process p;
  initial p = process::no_such_method;
endmodule
