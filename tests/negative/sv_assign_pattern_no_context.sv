// An assignment pattern in a context that supplies no type to shape it
// against -- here a system-task argument.
//
// This was a WARNING that returned null, and nothing counted an error.
// The caller propagated the null, the argument was dropped, and the
// compile SUCCEEDED: this file used to build and run, printing nothing
// where the pattern belonged. A dropped argument is a silent wrong
// result, so it is an error now.
module sv_assign_pattern_no_context;
  initial begin
    $display("%p", '{1, 2});
    $display("FAILED -- should not have compiled");
  end
endmodule
