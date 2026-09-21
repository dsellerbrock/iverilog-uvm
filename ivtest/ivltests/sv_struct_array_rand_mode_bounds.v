// Declared negative indices must use canonical storage leaves; OOB queries are OFF.
typedef struct {
  rand bit word[-2:0];
} bounds_query_config_t;

class query_bounds;
  rand bounds_query_config_t cfg;
endclass

module rand_mode_query_bounds_test;
  initial begin
    static query_bounds item = new;
    static int out_of_range = 99;
    item.cfg.word[-2].rand_mode(0);
    if (item.cfg.word[-2].rand_mode() !== 0)
      $fatal(1, "negative declared index did not query disabled");
    if (item.cfg.word[-1].rand_mode() !== 1)
      $fatal(1, "negative-index neighbor changed mode");
    if (item.cfg.word[out_of_range].rand_mode() !== 0)
      $fatal(1, "out-of-range query did not return inactive");
    $display("PASS rand-mode-query-bounds");
  end
endmodule
