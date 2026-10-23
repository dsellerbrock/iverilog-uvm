class C;
  int state_value;
  constraint c { state_value dist {1 := 1, 2 := 1}; }
endclass
module top;
  initial begin
    C object;
    object = new;
    $finish;
  end
endmodule
