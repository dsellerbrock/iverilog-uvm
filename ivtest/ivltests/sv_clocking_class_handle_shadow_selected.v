// A lexical class handle must shadow an enclosing clocking-block name.
// Its selected NBA is an ordinary class-property update, not a clocking drive.
class clocking_shadow_item;
  logic [7:0] raw;
endclass

module sv_clocking_class_handle_shadow_selected;
  timeunit 1ns;
  timeprecision 1ps;

  logic clk = 1'b0;
  logic [7:0] clocking_raw = 8'h3c;
  wire [7:0] raw;
  integer failures = 0;

  always #5 clk = ~clk;

  clocking shadow @(posedge clk);
    output raw = clocking_raw;
  endclocking

  initial begin : lexical_scope
    clocking_shadow_item shadow;

    shadow = new;
    shadow.raw = 8'ha0;
    shadow.raw[3:0] <= 4'h5;
    #1;

    if (shadow.raw !== 8'ha5) begin
      failures++;
      $display("FAILED class selected NBA raw=%h", shadow.raw);
    end
    // Wait past a clocking event so an incorrectly buffered drive would land.
    #5;
    if (clocking_raw !== 8'h3c) begin
      failures++;
      $display("FAILED shadowed clocking output was driven raw=%h",
               clocking_raw);
    end

    if (failures != 0)
      $fatal(1, "%0d class-handle shadow checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
