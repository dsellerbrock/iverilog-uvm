// IEEE 1800-2017/2023 7.6: a dynamic source with the wrong live count
// assigned to a fixed-size slice must raise a runtime error and do no write.
module test;
  logic data[];
  logic short_source[];
  logic saved[];

  initial begin
    data = new[8];
    short_source = new[3];
    foreach (data[i]) data[i] = (8'hb5 >> i) & 1;
    foreach (short_source[i]) short_source[i] = 1;
    saved = data;

    data[2 +: 4] = short_source;
    if (data.size() != 8)
      $fatal(1, "mismatched source resized a slice target");
    foreach (data[i])
      if (data[i] !== saved[i])
        $fatal(1, "mismatched source wrote element %0d", i);
    $display("PRESERVED after indexed dynamic-array slice size error");
  end
endmodule
