// Regression: an associative array whose VALUE is a queue, e.g.
//   bit [7:0] q[string][$];
//   q["a"].push_back(...); n = q["a"].size(); v = q["a"][i];
// (the OpenTitan cip_base scoreboard/cov member `exp_alert_q[string][$]`,
// shared across i2c/usbdev/pattgen).
//
// Two bugs, both fixed:
//  1. elaborate_array_type() built the unpacked dimensions inside-out, so
//     `[string][$]` became a queue-of-assoc instead of an assoc-of-queue
//     (string key ignored). Dimensions are now built outermost-first.
//  2. q["a"] (an assoc element select yielding a queue) set target_indexed,
//     which made the queue-method dispatch skip .size()/etc., folding size()
//     to a literal 0. The queue-method path now applies whenever the selected
//     value type is itself a queue.
module top;
  bit [7:0] q[string][$];
  int errors = 0;
  initial begin
    q["a"].push_back(8'hAA);
    q["a"].push_back(8'hBB);
    q["b"].push_back(8'h11);
    if (q["a"].size() != 2)       errors++;
    if (q["a"][0]   != 8'hAA)     errors++;
    if (q["a"][1]   != 8'hBB)     errors++;
    if (q["b"].size() != 1)       errors++;
    if (q["b"][0]   != 8'h11)     errors++;
    // mutate further and re-check
    q["a"].push_back(8'hCC);
    if (q["a"].size() != 3)       errors++;
    if (q["a"][2]   != 8'hCC)     errors++;
    if (errors == 0) $display("PASS");
    else $display("FAIL (%0d errors)", errors);
  end
endmodule
