class pattgen_word_repro;
  rand bit [31:0] value;
endclass
class pattgen_cfg_repro;
  int unsigned top_pct = 10, bottom_pct = 80, middle_pct = 10;
endclass
class pattgen_seq_repro;
  pattgen_cfg_repro cfg;
  function new(); cfg = new; endfunction
  function bit [63:0] get_data();
    pattgen_word_repro word;
    bit [31:0] lo;
    word = new;
    if (!word.randomize() with {
      value dist {32'hffffffff :/ cfg.top_pct, 32'h0 :/ cfg.bottom_pct,
                  [32'h1:32'hfffffffe] :/ cfg.middle_pct};
    }) $fatal(1, "low word randomize failed");
    lo = word.value;
    if (!word.randomize() with {
      value dist {32'hffffffff :/ cfg.top_pct, 32'h0 :/ cfg.bottom_pct,
                  [32'h0:32'hffffffff] :/ cfg.middle_pct};
    }) $fatal(1, "high word randomize failed");
    return {word.value, lo};
  endfunction
endclass
module pattgen_class_word_dist_repro;
  pattgen_seq_repro seq;
  bit [63:0] data;
  int low_zero, low_max, low_mid, high_zero, high_max, high_mid;
  initial begin
    seq = new;
    repeat (1000) begin
      data = seq.get_data();
      if (data[31:0] == 0) low_zero++;
      else if (data[31:0] == 32'hffffffff) low_max++;
      else low_mid++;
      if (data[63:32] == 0) high_zero++;
      else if (data[63:32] == 32'hffffffff) high_max++;
      else high_mid++;
    end
    if (low_zero < 650 || low_zero > 950 || low_max < 20 || low_mid < 20)
      $fatal(1, "low weighted data missing");
    if (high_zero < 650 || high_zero > 950 || high_max < 20 || high_mid < 20)
      $fatal(1, "high weighted data missing");
    $display("PASS low=%0d,%0d,%0d high=%0d,%0d,%0d",
             low_zero, low_max, low_mid, high_zero, high_max, high_mid);
  end
endmodule
