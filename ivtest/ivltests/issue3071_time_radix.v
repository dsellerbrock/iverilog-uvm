module issue3071_time_radix;
  time t;
  initial begin
    #5 t = $time;
    $display("%h|%h|%h|%o", $time, t, 64'd5, $time);
    $display("%h|%o|%b", $stime, $stime, $stime);
    $display("%0h|%0o|%0b|%3h|%18h", $time, $stime, $stime, $time, $time);
    $display("%0d|%0d", $time, $stime);
    #(64'd4294967296);
    $display("%h|%o|%h", $time, $time, $stime);
  end
endmodule
