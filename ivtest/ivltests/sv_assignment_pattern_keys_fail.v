// IEEE 1800-2017 10.9: malformed or incomplete keyed patterns are errors.
module test;
  typedef struct { int a; int b; } pair_t;
  typedef int ascending_t [1:3];
  int live_index;

  initial begin
    pair_t pair;
    ascending_t values;

    pair = '{missing:1, default:0};
    pair = '{a:1};
    values = '{4:1, default:0};
    values = '{1:1};
    values = '{live_index:1, default:0};
    values = '{1:1, 1:2, default:0};
    pair = '{a:1, a:2, default:0};
    pair = '{default:1, default:2};
  end
endmodule
