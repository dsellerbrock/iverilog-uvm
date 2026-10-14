class method_override_root;
  function :extends int value();
    return 1;
  endfunction
endclass

module test;
  method_override_root item;
  initial begin
    item = new;
    $display("%0d", item.value());
  end
endmodule
