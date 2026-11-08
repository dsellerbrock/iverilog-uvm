// An unpacked-struct open array is passed with the Annex H.7.8 aggregate
// layout (#2667); it used to be rejected instead of being marshaled.
module issue872_dpi_struct_open_array_fail;
  typedef struct {int a; int b;} s_t;
  import "DPI-C" function int c_struct_size(input s_t a[]);
  s_t arr[];
  initial begin
    arr = new[2];
    arr[1].b = 7;
    if (c_struct_size(arr) === 2 * 1000 + 7) $display("PASSED");
    else $display("FAILED: %0d", c_struct_size(arr));
  end
endmodule
