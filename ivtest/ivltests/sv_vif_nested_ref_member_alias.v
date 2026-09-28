// IEEE 1800-2017/2023 6.5, 13.5.2: a writable ref to one interface
// member must not make disjoint continuously driven members conflict.
`timescale 1ns/1ps

typedef struct packed {
  logic addr_req;
  logic data_req;
} otp_req_t;

interface flash_if(input logic clk);
  logic [1:0] hazard;
  otp_req_t otp_req;
  logic observed;
  logic driven;
  logic dut_out;
  clocking cb @(posedge clk);
    output driven;
    input observed;
  endclocking
endinterface

class flash_cfg;
  virtual flash_if vif;
  task drive(); vif.driven = 1'b0; endtask
endclass

class flash_seq;
  flash_cfg cfg;
  task automatic set_by_ref(ref logic sig);
    sig = 1'b1;
  endtask
  task body();
`ifdef REF_CONFLICT
    set_by_ref(cfg.vif.observed);
`elsif REF_CALL
    set_by_ref(cfg.vif.driven);
`endif
  endtask
endclass

module dut(output logic dout);
  assign dout = 1'b1;
endmodule

module top;
  logic clk, source;
  flash_if monitor(clk);
  flash_cfg cfg;
  flash_seq seq;
  for (genvar i = 0; i < 2; i++) begin
    assign monitor.hazard[i] = source;
  end
  assign monitor.otp_req.addr_req = source;
  assign monitor.observed = source;
  dut d(.dout(monitor.dut_out));
  initial begin
    source = 1'b1;
    cfg = new;
    cfg.vif = monitor;
    cfg.drive();
    seq = new;
    seq.cfg = cfg;
    seq.body();
    #1;
`ifdef REF_CALL
    if (monitor.driven !== 1'b1)
      $fatal(1, "nested ref did not write its selected member");
`else
    if (monitor.driven !== 1'b0)
      $fatal(1, "ordinary class-held VIF write changed");
`endif
    if (monitor.hazard !== 2'b11 || monitor.otp_req.addr_req !== 1'b1
        || monitor.observed !== 1'b1 || monitor.dut_out !== 1'b1)
      $fatal(1, "disjoint continuous interface members changed");
    $display("PASSED");
  end
endmodule
