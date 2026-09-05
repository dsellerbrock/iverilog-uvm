// IEEE 1800-2017 18.5.8.1 and 12.7.3;
// IEEE 1800-2023 18.5.7.1 and 12.7.3: foreach index types.
class sample;
  rand int data[];
  rand int selected;
  constraint c {
    // IEEE 1800-2017/2023 11.8.1/11.8.2: signed ternary result.
    selected == (1'b1 ? 2'sb11 : 4'sb0);
    data.size() == 2;
    foreach (data[i]) if (i > -1) data[i] == 17;
  }
endclass
module main;
  sample s;
  initial begin
    s = new;
    repeat (20) begin
      if (!s.randomize()) $fatal(1, "randomize failed");
      if (s.selected != -1) $fatal(1, "signed ternary result was not extended");
      foreach (s.data[j])
        if (s.data[j] != 17) $fatal(1, "index signedness lost at %0d: %0d", j, s.data[j]);
    end
    $display("PASSED");
  end
endmodule
