class constrained_item;
  rand bit stop_bit;
  constraint stop_bit_c { stop_bit == 1'b1; }
endclass

class sequence_holder;
  constrained_item req;

  task body;
    req = new;
    req.stop_bit_c.constraint_mode(0);
    if (!req.randomize() with { stop_bit == 1'b0; }) begin
      $error("named constraint_mode on a class property was ignored");
      $finish_and_return(1);
    end
    if (req.stop_bit != 1'b0) begin
      $error("inline constraint did not control class-property item");
      $finish_and_return(1);
    end
  endtask
endclass

module class_property_constraint_mode_test;
  sequence_holder seq;
  initial begin
    seq = new;
    seq.body();
    $display("PASSED: named constraint_mode on a class property");
    $finish;
  end
endmodule
