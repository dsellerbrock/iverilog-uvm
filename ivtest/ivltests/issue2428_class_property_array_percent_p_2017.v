module issue2428_class_property_array_percent_p_2017;
  class holder;
    int fx[0:2];
  endclass

  holder h;
  int module_array[0:2];

  initial begin
    h = new;
    h.fx[0] = 1;
    h.fx[1] = 2;
    h.fx[2] = 3;
    module_array[0] = 1;
    module_array[1] = 2;
    module_array[2] = 3;
    $display("%p", h.fx);
    $display("%p", module_array);
    $display("%0d", h.fx[1]);
  end
endmodule
