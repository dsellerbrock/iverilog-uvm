function automatic int count_ones(bit [9:0] w);
  count_ones = 0;
  for (; w != 0; w = w >> 1) count_ones += w & 1'b1;
endfunction

class G5;
  rand bit [9:0] v;
  rand bit [3:0] length;
  constraint c { (length < 3) -> (v[0] == 1); length == count_ones(v); }
endclass

module p18_05_12_depth_g5;
  G5 item;
  int ok, bad;
  initial begin
    item = new;
    repeat (200) begin
      if (item.randomize()) begin
        ok++;
        if (item.length != count_ones(item.v) ||
            ((item.length < 3) && (item.v[0] != 1))) bad++;
      end
    end
    $display("G5 ok=%0d bad=%0d", ok, bad);
    if (ok != 200 || bad != 0) $fatal(1, "G5 unexpected result");
  end
endmodule
