`timescale 1ns/1ps
module top;
  integer values [string];
  integer queue[$];
  string key;
  integer i, sum, old_value;
  initial begin
    sum = 0;
    for (i = 0; i < 1280000; i = i + 1) begin
      key = $sformatf("item_%0d", i & 255);
      values[key] = i ^ (i << 3);
      queue.push_back(values[key]);
      if (queue.size() > 64) begin
        old_value = queue.pop_front();
        sum = sum ^ old_value;
      end
    end
    while (queue.size() > 0) sum = sum + queue.pop_front();
    $display("containers=%0d sum=%0d", values.num(), sum);
    $finish;
  end
endmodule
