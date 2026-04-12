module test;
  class item_t;
    logic [1:0][7:0] data;
  endclass

  item_t item;

  initial begin
    item = new;
    item.data = 16'h1234;
    if (item.data !== 16'h1234) begin
      $display("FAIL data=%h", item.data);
      $finish(1);
    end
    $display("PASS");
  end
endmodule
