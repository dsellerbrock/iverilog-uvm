// IEEE 1800-2017/2023 10.4.2: capture the VIF receiver, selector, and RHS
// when an NBA executes; merge only the selected bits in the NBA region.
interface nba_selected_if;
  logic [3:0] bus;
endinterface

class nba_selected_driver;
  virtual nba_selected_if vif;
  logic [2:0] index;
  logic value;

  task drive();
    vif.bus[index] <= value;
  endtask
endclass

module sv_nba_vif_selected_bit_capture;
  nba_selected_if if0();
  nba_selected_if if1();
  nba_selected_driver drv;
  logic [2:0] index;
  logic value;
  integer signed base;
  integer errors = 0;

  initial begin
    drv = new;
    drv.vif = if0;
    if0.bus = 4'b0000;
    if1.bus = 4'b1111;
    drv.index = 0;
    drv.value = 1'b1;
    drv.drive();
    drv.index = 3;
    drv.value = 1'b0;
    drv.vif = if1;
    if (if0.bus !== 4'b0000) errors++;
    #0;
    if (if0.bus !== 4'b0000) errors++;
    #1;
    if (if0.bus !== 4'b0001 || if1.bus !== 4'b1111) errors++;

    // High bit, X/Z payloads, and an overlapping later NBA.
    index = 3;
    value = 1'bx;
    if0.bus[index] <= value;
    value = 1'b0;
    #1;
    if (if0.bus !== 4'bx001) errors++;
    index = 2;
    if0.bus[index] <= 1'bz;
    #1;
    if (if0.bus !== 4'bxz01) errors++;
    if0.bus[0] <= 1'b0;
    if0.bus[0] <= 1'b1;
    #1;
    if (if0.bus !== 4'bxz01) errors++;

    // Unknown and out-of-bounds selectors cannot alias bit zero.
    index = 3'bx01;
    if0.bus[index] <= 1'b0;
    index = 3'bz01;
    if0.bus[index] <= 1'b0;
    index = 7;
    if0.bus[index] <= 1'b0;
    #1;
    if (if0.bus !== 4'bxz01) errors++;

    // A signed indexed part-select overlaps the property at bit zero.
    if0.bus = 4'b0000;
    base = -1;
    if0.bus[base +: 3] <= 3'b101;
    base = 2;
    #0;
    if (if0.bus !== 4'b0000) errors++;
    #1;
    if (if0.bus !== 4'b0010) errors++;

    if (errors)
      $display("FAILED %0d", errors);
    else
      $display("PASSED");
  end
endmodule
