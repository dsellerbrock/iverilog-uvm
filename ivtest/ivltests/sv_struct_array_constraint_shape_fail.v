typedef struct {
  rand bit matrix[0:1][0:1];
  rand bit lane[3:2];
} invalid_member_array_t;
class invalid_member_array_holder;
  rand invalid_member_array_t cfg;
  constraint multidim { foreach (cfg.matrix[i]) cfg.matrix[i][0] == 1; }
  constraint outside { cfg.lane[4] == 1; }
endclass
module test; endmodule
