class unsupported_element;
  rand bit q[2][$];
  constraint elements { foreach (q[i,j]) q[i][j] == 1; }
endclass

module test;
  unsupported_element c;
  initial begin
    c = new;
    if (!c.randomize()) $display("PASSED");
    else $display("FAILED -- unsupported queue element was ignored");
  end
endmodule
