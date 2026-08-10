module test;
  class holder;
    const static int marker = 17;
  endclass

  initial begin
    holder::marker = 23;
    $display("FAILED marker=%0d", holder::marker);
  end
endmodule
