module r06_19j_class_property_bare_method;
  typedef enum {red, green, blue} Colors;
  class K; Colors col = green; endclass
  K k;
  initial begin
    k = new;
    $display("INFO class_next_bare=%0d", k.col.next);
    $display("INFO class_first_bare=%0d", k.col.first);
  end
endmodule
