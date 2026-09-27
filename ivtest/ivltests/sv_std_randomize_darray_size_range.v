// std::randomize() of a dynamic array or queue whose size is constrained to a
// range (IEEE 1800-2017/2023 18.12): the size is a random choice among the
// feasible values. Dynamic arrays were rejected, and a ranged size was an
// error (OpenTitan usbdev: std::randomize(tx_data) with
// { tx_data.size() <= MaxPktSizeByte; }).
module test;
  localparam int MaxPktSizeByte = 8;
  initial begin
    byte unsigned d[];
    byte unsigned q[$];
    int seen[int];
    bit ok, all_ok;
    all_ok = 1;
    repeat (200) begin
      ok = std::randomize(d) with { d.size() <= MaxPktSizeByte; d.size() > 0; };
      all_ok &= ok && d.size() >= 1 && d.size() <= MaxPktSizeByte;
      seen[d.size()] = 1;
    end
    ok = std::randomize(q) with { q.size() inside {[2:3]}; };
    all_ok &= ok && (q.size() == 2 || q.size() == 3);
    if (all_ok && seen.num() > 1) $display("PASSED");
    else $display("FAILED %0d %0d", all_ok, seen.num());
  end
endmodule
