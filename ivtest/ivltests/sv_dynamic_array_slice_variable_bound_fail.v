// IEEE 1800-2017/2023 7.4.5 makes a dynamic-array slice a fixed-size
// unpacked-array expression. Pin the supported direct constant-colon form,
// the intentionally loud indexed/nested boundaries, and required diagnostics
// for illegal forms; never silently model the result as another dynamic array.
module top;
  class holder;
    int data[];
  endclass

  int data[];
  int result[];
  real real_data[];
  holder object;
  int upper;
  real real_base;

  initial begin
    result = data[1:2]; // Supported direct constant-colon slice.
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
    result = data[0:2'bx];     // Colon bounds must be fully defined.
    result = real_data[0:1];   // Slice/target element types must be equivalent.
    object = new;
    result = object.data[0:1]; // Nested receiver support remains loud.
  end

  typedef union { int word; logic [31:0] bits; } union_t;
  union_t union_data[];
  union_t union_result[];
  initial begin
    union_result = union_data[0:1]; // Unpacked-union defaults remain loud.
  end
endmodule
