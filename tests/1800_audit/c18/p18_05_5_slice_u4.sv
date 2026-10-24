class U4;
  rand bit [1:0] a[4];
  rand bit [1:0] b;
  constraint c { unique {a[0:1], b}; }
endclass

module p18_05_5_slice_u4;
  U4 item;
  int ok, bad;
  initial begin
    item = new;
    repeat (50) begin
      if (item.randomize()) begin
        ok++;
        if (item.a[0] == item.a[1] || item.a[0] == item.b ||
            item.a[1] == item.b) bad++;
      end
    end
    $display("U4 ok=%0d bad=%0d", ok, bad);
  end
endmodule
