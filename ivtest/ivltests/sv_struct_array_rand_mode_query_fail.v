// The 18.8 function form requires a singular variable: no whole-array query.
typedef struct {
  rand bit word[1:0];
} whole_query_config_t;

class whole_query_negative;
  rand whole_query_config_t cfg;
endclass

module rand_mode_query_whole_negative_test;
  initial begin
    static whole_query_negative item = new;
    if (item.cfg.word.rand_mode()) $fatal(1, "whole-array query accepted");
  end
endmodule
