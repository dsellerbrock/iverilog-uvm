function automatic int count_ones(bit [9:0] w);
  count_ones = 0;
  for (; w != 0; w = w >> 1) count_ones += w & 1'b1;
endfunction

class G2;
  rand bit [9:0] v;
  rand bit [3:0] length;
  constraint c { length == count_ones(v); length < 3; }
endclass

module p18_05_12_depth_g2;
  G2 item;
  int ok, bad;
  initial begin
    item = new;
    repeat (200) begin
      if (item.randomize()) begin
        ok++;
        if (item.length != count_ones(item.v) || item.length >= 3) bad++;
      end
    end
    $display("G2 ok=%0d bad=%0d", ok, bad);
    if (ok < 1 || ok > 27 || bad != 0) $fatal(1, "G2 unexpected result");
  end
endmodule
