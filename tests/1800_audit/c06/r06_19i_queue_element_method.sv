module r06_19i_queue_element_method;
  typedef enum {red, green, blue, yellow} Colors;
  Colors q[$];
  initial begin
    q.push_back(yellow);
    $display("INFO queue_name=%s", q[0].name());
    $display("INFO queue_next=%0d", q[0].next());
  end
endmodule
