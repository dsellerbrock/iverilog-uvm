// Non-bit-stream element types and associative arrays are not legal
// dynamically sized streaming targets (IEEE 1800-2017 11.4.14.1/11.4.14.4).
module test;
  real real_data[];
  byte assoc[int];
  initial begin
    {>>{real_data}} = 64'h0;
    {>>{assoc}} = 32'h0;
  end
endmodule
