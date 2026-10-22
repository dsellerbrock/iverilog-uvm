class U3;
  rand bit [1:0] a[4];
  int i = 1;
  constraint c { unique {a[i:i+1]}; }
endclass

module p18_05_5_slice_u3;
  U3 item;
  int ok, bad;
  initial begin
    item = new;
    repeat (50) begin
      if (item.randomize()) begin
        ok++;
        if (item.a[1] == item.a[2]) bad++;
      end
    end
    $display("U3 ok=%0d bad=%0d", ok, bad);
  end
endmodule
