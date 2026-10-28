class c_type;
  int value;
endclass

module issue1252_dpi_class_arg;
  import "DPI-C" function int c_class(input c_type value);
  c_type obj;
  int result;

  initial begin
    obj = new;
    result = c_class(obj);
    $display("result=%0d", result);
    $finish;
  end
endmodule
