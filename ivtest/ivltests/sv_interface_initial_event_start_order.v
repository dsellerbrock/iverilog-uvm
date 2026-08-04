// Startup processes are unordered by IEEE 1800, but simulators choose a
// deterministic order.  Run an instantiated interface's process before its
// containing module's process so that the interface can arm a one-shot event
// waiter before the parent calls its startup method.  Defining the interface
// after its user also checks that hierarchy-ready ordering takes precedence
// over the otherwise lexical order of normal initial processes.
module top;
  wire clk;
  wire rst_n;
  wire clk_aon;
  wire rst_aon_n;
  startup_if vif(clk, rst_n);
  startup_if aon_vif(clk_aon, rst_aon_n);

  initial begin
    aon_vif.set_active();
    vif.set_active();
    #1;
    if (vif.armed !== 1'b1) begin
      $display("FAILED -- interface startup process was not armed");
      $finish;
    end
    if (vif.observed !== 1'b1) begin
      $display("FAILED -- interface startup event was missed");
      $finish;
    end
    if (aon_vif.observed !== 1'b1) begin
      $display("FAILED -- second interface startup event was missed");
      $finish;
    end
    if (vif.gate !== 1'b0 || vif.period != 20_000) begin
      $display("FAILED -- interface static initialization order changed");
      $finish;
    end
    $display("PASSED");
    $finish;
  end
endmodule

interface startup_if(inout wire clk, inout wire rst_n);
  event active;
  bit armed;
  bit observed;
  bit gate = 1'b0;
  int period = 20_000;

  initial begin
    armed = 1'b1;
    @active;
    observed = 1'b1;
  end

  function automatic void set_active();
    -> active;
  endfunction
endinterface
