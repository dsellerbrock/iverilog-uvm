interface bus_if(input logic clk);
  typedef struct packed {
    logic       valid;
    logic [3:0] data;
  } req_t;

  req_t raw;
  wire req_t bus;

  clocking cb @(posedge clk);
    output bus = raw;
  endclocking
endinterface

class driver;
  virtual bus_if vif;

  function new(virtual bus_if vif);
    this.vif = vif;
  endfunction

  task drive_fields;
    @(vif.cb);
    vif.cb.bus.valid <= 1'b1;
    vif.cb.bus.data  <= 4'ha;
  endtask

  task drive_whole;
    @(vif.cb);
    vif.cb.bus <= 5'b0_0101;
  endtask
endclass

module top;
  bit clk;
  bus_if intf(clk);
  driver drv;

  always #5 clk = !clk;

  initial begin
    drv = new(intf);
    drv.drive_fields();
    @(posedge clk);
    #1;
    if (intf.raw.valid !== 1'b1 || intf.raw.data !== 4'ha) begin
      $error("field drive missed clocking_decl_assign target: raw=%b", intf.raw);
      $finish_and_return(1);
    end

    drv.drive_whole();
    @(posedge clk);
    #1;
    if (intf.raw.valid !== 1'b0 || intf.raw.data !== 4'h5) begin
      $error("whole drive missed clocking_decl_assign target: raw=%b", intf.raw);
      $finish_and_return(1);
    end

    $display("PASSED: virtual-interface clocking output aliases");
    $finish;
  end
endmodule
