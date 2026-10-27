function automatic int count_ones(bit [9:0] w);
  count_ones = 0;
  for (; w != 0; w = w >> 1) count_ones += w & 1'b1;
endfunction

class G1;
  int s = 3'b011;
  rand bit [3:0] length;
  constraint c { length == count_ones(s); length < 3; }
endclass

module p18_05_12_depth_g1;
  G1 item;
  int ok, bad;
  initial begin
    item = new;
    repeat (50) begin
      if (!item.randomize()) bad++;
      else begin
        ok++;
        if (item.length != 2) bad++;
      end
    end
    $display("G1 ok=%0d bad=%0d length=%0d", ok, bad, item.length);
    if (ok != 50 || bad != 0) $fatal(1, "G1 unexpected result");
  end
endmodule
