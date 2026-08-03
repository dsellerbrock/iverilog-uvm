// IEEE 1800-2017 14.16 and 10.4.2: nonblocking assignments to a
// packed member of a clocking output use the same clocking-output buffer and
// NBA ordering as an assignment to the whole clockvar.
interface m8_vif_clocking_packed_if(input logic clk);
  typedef struct packed {
    logic       valid;
    logic [7:0] data;
  } req_t;

  req_t raw;
  wire req_t bus;

  clocking cb @(posedge clk);
    output bus = raw;
  endclocking
endinterface

class m8_vif_clocking_packed_driver;
  virtual m8_vif_clocking_packed_if vif;

  task drive();
    @(vif.cb);

    // Model a protocol driver invalidating the previous transfer and then
    // immediately launching the next one in the same process and time slot.
    // The later member assignments must win for their selected bits.
    vif.cb.bus       <= '0;
    vif.cb.bus.data  <= 8'ha5;
    vif.cb.bus.valid <= 1'b1;
  endtask
endclass

module m8_vif_clocking_packed_member_nba_test;
  logic clk = 0;
  m8_vif_clocking_packed_if intf(clk);
  m8_vif_clocking_packed_driver drv;

  always #5 clk = ~clk;

  initial begin
    drv = new;
    drv.vif = intf;
    fork
      drv.drive();
    join_none

    #6;
    if (intf.raw !== 9'h1a5) begin
      $display("FAILED: packed clocking member NBA ordering raw=%h", intf.raw);
      $finish_and_return(1);
    end

    $display("PASSED: packed clocking member NBA ordering");
    $finish;
  end
endmodule
