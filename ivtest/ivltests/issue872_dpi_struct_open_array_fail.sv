// An unpacked-struct open array needs the Annex H.7.8 aggregate layout,
// which is not implemented: the import must not compile into a call that
// is silently skipped.
module issue872_dpi_struct_open_array_fail;
  typedef struct {int a; int b;} s_t;
  import "DPI-C" function int c_struct_size(input s_t a[]);
  s_t arr[];
  initial begin
    arr = new[2];
    $display("%0d", c_struct_size(arr));
  end
endmodule
