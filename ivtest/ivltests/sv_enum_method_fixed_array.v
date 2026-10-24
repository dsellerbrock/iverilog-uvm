// Enum value methods accept an element of a fixed unpacked array.
// IEEE 1800-2017/2023 6.19.5.3 and 6.19.5.6.
module test;
  typedef enum {red, green, blue, yellow} Colors;
  Colors arr[2];
  Colors next_color;

  initial begin
    arr[1] = blue;
    next_color = arr[1].next();
    if (arr[1].name() != "blue" || next_color != yellow)
      $fatal(1, "FAILED: name=%s next=%s", arr[1].name(), next_color.name());
    else
      $display("PASSED");
  end
endmodule
