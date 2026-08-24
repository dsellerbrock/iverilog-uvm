// IEEE 1800-2017/2023 7.4.5 makes a dynamic-array slice a fixed-size
// unpacked-array expression. Pin both the currently loud implementation
// boundary for legal slices and the required diagnostics for illegal forms;
// never silently model the result as another dynamic array.
module top;
  int data[];
  int result[];
  int upper;
  real real_base;

  initial begin
    result = data[1:2]; // Legal, but fixed-size r-value support is pending.
    upper = 2;
    result = data[upper +: 2]; // Legal variable position, same boundary.
    result = data[0:upper];    // Colon bounds must be constant.
    result = data[0:$];        // `$' is a queue-only endpoint.
    result = data[2:1];        // Dynamic arrays have ascending direction.
    result = data[0 +: upper]; // Indexed width must be constant.
    result = data[0 +: 0];     // Indexed width must be positive.
    result = data[0 +: -1];    // A negative width is also invalid.
    result = data[0 +: 1'bx];  // An unknown width is not positive/defined.
    result = data[real_base +: 1]; // Indexed base must be integral.
  end
endmodule
