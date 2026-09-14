package existing_pkg;
endpackage

class holder;
  function void missing;
    $display("WRONG_LOCAL_METHOD");
  endfunction

  task invoke;
    existing_pkg::missing();
  endtask
endclass

module test;
  holder value;
  initial begin
    value = new;
    value.invoke();
  end
endmodule
