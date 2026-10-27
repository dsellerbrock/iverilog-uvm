module r06_19g_class_property_method;
  typedef enum {red, green, blue} Colors;
  class K; Colors col = green; endclass
  K k;
  initial begin
    k = new;
    $display("INFO class_name=%s", k.col.name());
    $display("INFO class_next=%0d", k.col.next());
    $display("INFO class_first=%0d", k.col.first());
  end
endmodule
