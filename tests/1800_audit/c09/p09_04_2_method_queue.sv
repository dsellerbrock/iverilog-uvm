module top; int qq[$]; int hit;
  initial begin @(qq.size()); hit = 1; end
  initial begin #5 qq.push_back(1); #1 $display("%s 9.4.2.queue_size_event hit=%0d", hit == 1 ? "PASS" : "FAIL", hit); $finish; end
endmodule
