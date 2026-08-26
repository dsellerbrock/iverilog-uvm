module top;
  import "DPI-C" function int dpi_prefixless_add(input int value);

  initial begin
    int result;
    result = dpi_prefixless_add(40);
    if (result !== 42) begin
      $display("FAIL prefixless DPI vec4 call: result=%0d", result);
      $finish(1);
    end
    $display("PASS prefixless DPI vec4 call compatibility");
    $finish(0);
  end
endmodule
