// A scalar selected from a fixed child is not an ordering-method receiver.
typedef enum int { Data, Info } part_t;
class cfg_t;
  bit [3:0] map[part_t][4];
endclass
module top;
  cfg_t cfg;
  initial begin
    cfg = new;
    cfg.map[Data][0].shuffle();
  end
endmodule
