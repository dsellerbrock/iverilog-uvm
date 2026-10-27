typedef struct {
  int value;
} item_t;

module p35_struct_openarray;
  import "DPI-C" function int c_array_size(input item_t values[]);

  item_t values[2];

  initial begin
    values[0].value = 10;
    values[1].value = 20;
    if (c_array_size(values) != 2)
      $fatal(1, "wrong structure open-array size");
    $display("PASS structure open-array size=2");
    $finish;
  end
endmodule
