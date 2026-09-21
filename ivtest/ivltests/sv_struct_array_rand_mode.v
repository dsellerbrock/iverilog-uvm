// IEEE 1800-2017/2023 18.8: function-form rand_mode selects one array element.
typedef struct {
  rand bit word[4:2];
} query_config_t;

class query_positive;
  rand query_config_t cfg;
endclass

module rand_mode_query_positive_test;
  initial begin
    static query_positive item = new;
    item.cfg.word[4].rand_mode(0);
    if (item.cfg.word[4].rand_mode() !== 0)
      $fatal(1, "disabled descending member element queried active");
    if (item.cfg.word[3].rand_mode() !== 1)
      $fatal(1, "neighbor member element was disabled");
    item.cfg.word[4].rand_mode(1);
    if (item.cfg.word[4].rand_mode() !== 1)
      $fatal(1, "re-enabled member element queried inactive");
    $display("PASS rand-mode-query-positive");
  end
endmodule
