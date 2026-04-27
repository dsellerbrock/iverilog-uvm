class DataItem;
  rand bit [7:0] data;
  rand bit [7:0] addr;
  constraint base { data > 8'd0; }
endclass

module top;
  DataItem item;
  int ok, failed = 0;
  bit [7:0] max_addr = 8'd63;
  bit [7:0] expected = 8'hAB;
  initial begin
    item = new();

    // Test 1: constant in with-constraint
    repeat (5) begin
      ok = item.randomize() with { data == 8'hAB; };
      if (item.data !== 8'hAB) failed++;
    end
    $display("T1 (const): %s", failed == 0 ? "PASS" : "FAIL");

    // Test 2: caller-scope variable in with-constraint
    repeat (5) begin
      ok = item.randomize() with { addr <= max_addr; };
      if (item.addr > max_addr) failed++;
    end
    $display("T2 (local var): %s", failed == 0 ? "PASS" : "FAIL");

    // Test 3: caller-scope variable equality
    repeat (5) begin
      ok = item.randomize() with { data == expected; };
      if (item.data !== expected) failed++;
    end
    $display("T3 (local var eq): %s", failed == 0 ? "PASS" : "FAIL");

    // Test 4: combined with-constraint
    repeat (5) begin
      ok = item.randomize() with { data inside {[8'd10:8'd20]}; };
      if (item.data < 10 || item.data > 20) failed++;
    end
    $display("T4 (inside range): %s", failed == 0 ? "PASS" : "FAIL");

    if (failed == 0)
      $display("randomize_with PASSED!");
    else
      $display("FAILED: %0d violations", failed);
  end
endmodule
