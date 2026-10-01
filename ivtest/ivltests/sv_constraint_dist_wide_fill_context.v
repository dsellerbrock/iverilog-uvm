// IEEE 1800-2017/2023 11.8.2, 18.5.4/18.5.3: dist operands get
// the 65-bit subject context, including unbased fill arithmetic.
class wide_fill_dist;
  rand bit [64:0] alert_regwen;
  rand bit [64:0] alert_en;
  rand bit [64:0] complement_source;
  bit [64:0] wanted_regwen, wanted_en, wanted_complement;
  constraint smoke_c {
    alert_regwen dist {[0:'1-1'b1] :/ 4, '1 :/ 6};
  }
  constraint entropy_c {
    alert_en dist {'1 :/ 9, [0:('1-1'b1)] :/ 1};
    (~complement_source) dist {'1 :/ 9, [0:('1-1'b1)] :/ 1};
  }
  constraint fixed_c {
    alert_regwen == wanted_regwen;
    alert_en == wanted_en;
    complement_source == wanted_complement;
  }
endclass

module test;
  wide_fill_dist cfg;
  initial begin
    cfg = new;
    cfg.wanted_regwen = 65'h1_ffff_ffff_ffff_fffe;
    cfg.wanted_en = 65'h1_ffff_ffff_ffff_ffff;
    cfg.wanted_complement = 65'h0;
    if (!cfg.randomize() || cfg.alert_regwen !== cfg.wanted_regwen
        || cfg.alert_en !== cfg.wanted_en
        || cfg.complement_source !== cfg.wanted_complement)
      $fatal(1, "65-bit high-end dist context");
    cfg.wanted_regwen = 65'h1_ffff_ffff_ffff_ffff;
    cfg.wanted_en = 65'h1_ffff_ffff_ffff_fffe;
    cfg.wanted_complement = 65'h1;
    if (!cfg.randomize() || cfg.alert_regwen !== cfg.wanted_regwen
        || cfg.alert_en !== cfg.wanted_en
        || cfg.complement_source !== cfg.wanted_complement)
      $fatal(1, "65-bit max and range dist context");
    $display("PASSED");
  end
endmodule
