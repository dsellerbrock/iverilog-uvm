// IEEE 1800-2017/2023 7.5, 18.4: outer size changes retain inner values.
typedef struct packed { bit value; } nested_filter_t;

class nested_resize_two;
  rand nested_filter_t filter_cfg[][];
  constraint size_c { filter_cfg.size == 2; }
endclass

class nested_resize_zero;
  rand nested_filter_t filter_cfg[][];
  constraint size_c { filter_cfg.size == 0; }
endclass

class nested_resize_impossible;
  rand nested_filter_t filter_cfg[][];
  constraint size_c { filter_cfg.size == 2; filter_cfg.size == 3; }
endclass

module test;
  nested_resize_two grown = new;
  nested_resize_zero emptied = new;
  nested_resize_impossible failed = new;
  initial begin
    grown.filter_cfg = new[1];
    grown.filter_cfg[0] = new[1];
    grown.filter_cfg[0][0].value = 1;
    if (!grown.randomize()) $fatal(1, "outer growth failed");
    if (grown.filter_cfg.size() != 2
        || grown.filter_cfg[0].size() != 1
        || grown.filter_cfg[0][0].value != 1
        || grown.filter_cfg[1].size() != 0)
      $fatal(1, "outer growth lost an inner value or initialized a new row");

    emptied.filter_cfg = new[1];
    emptied.filter_cfg[0] = new[1];
    if (!emptied.randomize() || emptied.filter_cfg.size() != 0)
      $fatal(1, "zero outer size failed");

    failed.filter_cfg = new[1];
    failed.filter_cfg[0] = new[1];
    failed.filter_cfg[0][0].value = 1;
    if (failed.randomize() || failed.filter_cfg.size() != 1
        || failed.filter_cfg[0].size() != 1
        || failed.filter_cfg[0][0].value != 1)
      $fatal(1, "impossible size changed the original value");
    $display("PASSED");
  end
endmodule
