module test;
  class box #(int VALUE = 1);
  endclass

  box#(1) item;

  initial begin
    item = box#(2)::new;
    $display("FAILED");
  end
endmodule
