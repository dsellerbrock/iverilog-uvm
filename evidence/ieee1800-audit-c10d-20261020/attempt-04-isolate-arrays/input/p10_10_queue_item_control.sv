module p10_10_queue_item_control;
  int q[$], C[];
  initial begin
    q = '{7, 8};
    C = {q};
    $display("Q %0d %0d %0d", C.size(), C[0], C[1]);
  end
endmodule
