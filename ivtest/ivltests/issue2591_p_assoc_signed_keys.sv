// IEEE 1800-2017/2023 7.8.4 / 21.2.1.7: an associative array with a signed
// index type orders its keys as signed numbers, and %p prints them that way.
module issue2591_p_assoc_signed_keys;
  int m[int];
  byte b[byte];
  longint l[longint];
  int unsigned u[int unsigned];
  string s;
  bit ok = 1;

  task automatic expect_str(string got, string want);
    if (got != want) begin
      $display("FAILED: %s, expected %s", got, want);
      ok = 0;
    end
  endtask

  initial begin
    m[3] = 30; m[-1] = 10; m[-7] = 70;
    b[8'sd5] = 1; b[-8'sd2] = 2;
    l[-64'sd5] = 5; l[64'sd4] = 4;
    u[3] = 30; u[32'hffffffff] = 10;
    s = $sformatf("%p", m); expect_str(s, "'{-7:70, -1:10, 3:30}");
    s = $sformatf("%p", b); expect_str(s, "'{-2:2, 5:1}");
    s = $sformatf("%p", l); expect_str(s, "'{-5:5, 4:4}");
    s = $sformatf("%p", u); expect_str(s, "'{3:30, 4294967295:10}");
    if (ok) $display("PASSED");
  end
endmodule
