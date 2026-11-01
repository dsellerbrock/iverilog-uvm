// IEEE 1800-2017/2023 18.4.2: a sparse wide randc domain must cycle exactly.
class randc_extension_item;
  randc bit [20:0] value;
  bit impossible;
  constraint legal_values {
    value inside {[0:64]};
    if (impossible) value == 65;
  }
endclass

class expanded_domain_item;
  randc bit [20:0] value;
  constraint legal_values { value inside {[0:2048]}; }
endclass

module test;
  initial begin
    randc_extension_item item;
    expanded_domain_item expanded;
    bit [64:0] seen;
    bit [20:0] previous;
    item = new;
    expanded = new;
    seen = '0;
    item.srandom(32'h4200065);
    expanded.srandom(32'h4200801);
    if (!expanded.randomize())
      $fatal(1, "randomize rejected the 2049-value randc domain");
    for (int unsigned i = 0; i < 65; i++) begin
      if (i == 32) begin
        previous = item.value;
        item.impossible = 1;
        if (item.randomize() || item.value !== previous)
          $fatal(1, "failed randomize changed randc value");
        item.impossible = 0;
      end
      if (!item.randomize()) $fatal(1, "randomize failed at %0d", i);
      if (item.value > 64 || seen[item.value])
        $fatal(1, "randc repeated or escaped its domain at %0d", i);
      seen[item.value] = 1'b1;
    end
    $display("PASSED");
  end
endmodule
