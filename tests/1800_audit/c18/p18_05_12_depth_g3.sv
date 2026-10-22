function automatic int count_ones(bit [9:0] w);
  count_ones = 0;
  for (; w != 0; w = w >> 1) count_ones += w & 1'b1;
endfunction

class G3;
  rand bit [9:0] v;
  rand bit [3:0] length;
  constraint c { length == count_ones(v); }
endclass

module p18_05_12_depth_g3;
  G3 item;
  int ok, bad;
  initial begin
    item = new;
    repeat (200) begin
      if (item.randomize() with { length < 3; }) begin
        ok++;
        if (item.length != count_ones(item.v) || item.length >= 3) bad++;
      end
    end
    $display("G3 ok=%0d bad=%0d", ok, bad);
    if (ok < 1 || ok > 27 || bad != 0) $fatal(1, "G3 unexpected result");
  end
endmodule
