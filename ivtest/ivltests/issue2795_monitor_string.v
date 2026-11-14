// IEEE 1800-2023 21.2.3: $monitor displays its argument list each time a
// variable in it changes value; a string variable is one.
module issue2795_monitor_string;
  string s;
  integer a;
  initial begin
    s = "x"; a = 0;
    $monitor("%0t s=%s a=%0d", $time, s, a);
    #1 s = "y";
    #1 a = 1;
    #1 s = "longer";
    #1 s = "longer";   // same value: no new line
    #1 $display("%0t end", $time);
  end
endmodule
