class U5;
  rand bit [1:0] a[4];
  constraint c { unique {a}; }
endclass

module p18_05_5_slice_u5;
  U5 item;
  int ok, bad, i, j;
  initial begin
    item = new;
    repeat (50) begin
      if (item.randomize()) begin
        ok++;
        for (i = 0; i < 4; i++)
          for (j = i + 1; j < 4; j++)
            if (item.a[i] == item.a[j]) bad++;
      end
    end
    $display("U5 ok=%0d bad=%0d", ok, bad);
  end
endmodule
