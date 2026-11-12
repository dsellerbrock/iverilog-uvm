module issue2619_queue_fixed_array_increment;
  bit [7:0] q[$][3:2];

  initial begin
    q.push_back('{8'h01, 8'h02});
    q[0][3]++;
    if (q[0][3] !== 8'h02 || q[0][2] !== 8'h02)
      $fatal(1, "queue fixed-array increment mismatch: %h %h",
             q[0][3], q[0][2]);
    $display("%h %h", q[0][3], q[0][2]);
  end
endmodule
