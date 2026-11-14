module top;
  task automatic inspect_me;
    disable fork;
    disable inspect_me;
    $display("not called");
  endtask
  initial begin $inspect; $finish(0); end
endmodule
