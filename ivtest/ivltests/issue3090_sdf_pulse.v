`timescale 1ns/1ns
module issue3090_buf(input a, output y);
  buf (y, a);
  specify (a => y) = 5; endspecify
endmodule

module issue3090_sdf_pulse;
  reg a = 0;
  reg x = 0;
  wire direct_y, increment_y, preserve_y, default_y, error_y, two_y, added_y, distinct_y;
  wire x_y;
  issue3090_buf direct_u(a, direct_y), increment_u(a, increment_y),
                preserve_u(a, preserve_y), default_u(a, default_y),
                error_u(a, error_y), two_u(a, two_y), added_u(a, added_y),
                distinct_u(a, distinct_y);
  issue3090_buf x_u(x, x_y);
  initial begin
    $sdf_annotate("ivltests/issue3090_sdf_pulse.sdf", issue3090_sdf_pulse);
    #10 a = 1; x = 1'bx;
    #2 a = 0;
    #4;
    if (direct_y !== 1 || increment_y !== 1 || preserve_y !== 1 ||
        default_y !== 0 || error_y !== 1'bx || two_y !== 1 || distinct_y !== 0)
      $fatal(1, "pulse outputs direct=%b increment=%b preserve=%b default=%b error=%b two=%b distinct=%b",
             direct_y, increment_y, preserve_y, default_y, error_y, two_y, distinct_y);
    #2;
    if (added_y !== 1) $fatal(1, "incremented pulse was rejected");
    if (x_y !== 0) $fatal(1, "X transition did not retain its earlier delay");
    #1;
    if (direct_y !== 0 || increment_y !== 0 || preserve_y !== 0 ||
        default_y !== 0 || error_y !== 0 || two_y !== 0)
      $fatal(1, "pulse did not end");
    #2;
    if (added_y !== 0) $fatal(1, "incremented pulse did not end");
    if (x_y !== 1'bx) $fatal(1, "incremented X transition did not arrive");
    $display("PASSED");
    $finish;
  end
endmodule
