module r06_19h_array_element_method;
  typedef enum {red, green, blue, yellow} Colors;
  Colors arr[2];
  initial begin
    arr[1] = blue;
    $display("INFO array_name=%s", arr[1].name());
    $display("INFO array_next=%0d", arr[1].next());
  end
endmodule
