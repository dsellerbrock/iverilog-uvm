// IEEE 1800-2017/2023 7.6: the entire slice RHS is sampled before a
// blocking assignment stores any selected destination element.
module test;
  logic data[];
  logic snapshot[];

  initial begin
    data = new[16];
    foreach (data[i]) data[i] = (16'hd2b5 >> i) & 1;
    snapshot = data;

    data[4 +: 8] = data[0 +: 8];
    if (data.size() != 16)
      $fatal(1, "overlap changed dynamic-array size");
    for (int i = 0; i < 16; i++) begin
      if (i >= 4 && i < 12) begin
        if (data[i] !== snapshot[i-4])
          $fatal(1, "overlap lost RHS snapshot at %0d", i);
      end else if (data[i] !== snapshot[i])
        $fatal(1, "overlap changed unselected word at %0d", i);
    end
    $display("PASS indexed dynamic-array overlap");
  end
endmodule
