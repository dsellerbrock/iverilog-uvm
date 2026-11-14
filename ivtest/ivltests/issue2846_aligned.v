module issue2846_aligned;
  typedef byte queue_t[$];
  typedef byte array_t[];
  queue_t q;
  array_t a;
  initial begin
    q = queue_t'(24'h123456);
    a = array_t'(24'habcdef);
    if (q.size() != 3 || q[0] !== 8'h12 || q[1] !== 8'h34 || q[2] !== 8'h56 ||
        a.size() != 3 || a[0] !== 8'hab || a[1] !== 8'hcd || a[2] !== 8'hef)
      $fatal(1, "incorrect bit stream");
    $display("PASS");
  end
endmodule
