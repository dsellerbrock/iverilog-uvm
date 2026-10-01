class base_reg #(type KEY_T = string);
  int fields[4];
  int named_fields[KEY_T];
endclass

class derived_reg extends base_reg #(string);
  int derived_only;
endclass

class base_cfg #(type RAL_T = base_reg);
  RAL_T ral;
endclass

class mid_cfg #(type RAL_T = base_reg) extends base_cfg #(RAL_T);
endclass

class actual_cfg extends mid_cfg #(derived_reg);
endclass

class base_cov #(type CFG_T = base_cfg);
  CFG_T cfg;
endclass

class actual_cov extends base_cov #(actual_cfg);
  function void check();
    int fixed_count;
    int named_count;
    fixed_count = 0;
    named_count = 0;
    foreach (cfg.ral.fields[i]) begin
      if (i < 0 || i > 3) $fatal(1, "bad fixed index %0d", i);
      fixed_count++;
    end
    foreach (cfg.ral.named_fields[key]) begin
      if (key != "left" || cfg.ral.named_fields[key] != 5)
        $fatal(1, "bad associative index %s", key);
      named_count++;
    end
    if (fixed_count != 4 || named_count != 1)
      $fatal(1, "bad foreach counts %0d %0d", fixed_count, named_count);
  endfunction
endclass

module top;
  initial begin
    actual_cov cov;
    cov = new;
    cov.cfg = new;
    cov.cfg.ral = new;
    cov.cfg.ral.derived_only = 17;
    cov.cfg.ral.named_fields["left"] = 5;
    cov.check();
    if (cov.cfg.ral.derived_only != 17)
      $fatal(1, "lost derived RAL type");
    $display("PASSED");
  end
endmodule
