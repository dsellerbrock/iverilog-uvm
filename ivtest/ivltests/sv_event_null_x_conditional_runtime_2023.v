interface null_cond_if;
  logic wake;
endinterface
class null_cond_cfg;
  virtual null_cond_if vif;
endclass
module test;
  null_cond_if bus();
  null_cond_cfg cfg;
  logic select = 1'bx;
  logic plain = 0;
  initial begin
    cfg = new;
    cfg.vif = null;
    @(posedge (select ? cfg.vif.wake : plain));
    $fatal(1, "ambiguous conditional null use was not fatal");
  end
endmodule
