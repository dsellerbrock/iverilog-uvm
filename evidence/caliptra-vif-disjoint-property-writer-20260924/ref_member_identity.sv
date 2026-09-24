`timescale 1ns/1ps

interface ref_member_if;
  logic count;
  logic reset;
endinterface

module ref_member_producer(output logic count);
  assign count = 1'b0;
endmodule

module ref_disjoint;
  ref_member_if bus();
  ref_member_producer dut(bus.count);
  virtual ref_member_if vif;
  task automatic write_ref(ref logic target);
    target = 1'b1;
  endtask
  initial begin
    vif = bus;
    write_ref(vif.reset);
    #1;
    if (bus.count !== 1'b0 || bus.reset !== 1'b1)
      $fatal(1, "disjoint ref failed");
    $display("PASSED");
  end
endmodule

module direct_disjoint;
  ref_member_if bus();
  ref_member_producer dut(bus.count);
  virtual ref_member_if vif;
  initial begin
    vif = bus;
    vif.reset = 1'b1;
    #1;
    if (bus.count !== 1'b0 || bus.reset !== 1'b1)
      $fatal(1, "disjoint direct write failed");
    $display("PASSED");
  end
endmodule

module ref_same_member;
  ref_member_if bus();
  ref_member_producer dut(bus.count);
  virtual ref_member_if vif;
  task automatic write_ref(ref logic target);
    target = 1'b1;
  endtask
  initial begin
    vif = bus;
    write_ref(vif.count);
  end
endmodule
