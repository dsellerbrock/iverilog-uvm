package p;
class bitflip_mask_generator #(int W = 39);
    rand logic [W-1:0] m;
    function new; m = '0; endfunction
    function logic [W-1:0] get_mask(bit d = 1'b0); this.randomize(); return m; endfunction
endclass
typedef struct packed {
    logic dccm_double_bit_error;
    logic dccm_single_bit_error;
    logic iccm_double_bit_error;
    logic iccm_single_bit_error;
} mode_t;
endpackage
module t;
  import p::*;
  logic clk = 0, rst_b = 0;
  mode_t mode;
  logic [3:0] wren = 0; logic [3:0] clken = 0;
  bit   [3:0]       dccm_flip_bit;
  logic [3:0][38:0] dccm_sram_wdata_bitflip;
  int jj;
  always #5 clk = ~clk;
  always @(negedge clk or negedge rst_b) begin
    if (!rst_b) mode <= '{default: 1'b0};
  end
  initial begin
    bitflip_mask_generator #(39) gen = new();
    forever begin
      @(posedge clk)
      if (~mode.dccm_single_bit_error && ~mode.dccm_double_bit_error) begin
        dccm_sram_wdata_bitflip <= '{default:0};
      end
      else if (clken & wren) begin
        for (jj = 0; jj < 4; jj++) begin
          dccm_flip_bit[jj] = 1'($urandom_range(0,99) < 50);
          dccm_sram_wdata_bitflip[jj] <= dccm_flip_bit[jj] ? gen.get_mask(mode.dccm_double_bit_error) : '0;
        end
      end
    end
  end
  wire [38:0] d0 = 39'h12_3456_789a ^ dccm_sram_wdata_bitflip[0];
  wire [38:0] d3 = 39'h12_3456_789a ^ dccm_sram_wdata_bitflip[3];
  initial begin
    #1 rst_b = 0; #20 rst_b = 1;
    repeat (4) @(posedge clk);
    #1 $display("mode=%b bitflip=%h d0=%h d3=%h", mode, dccm_sram_wdata_bitflip, d0, d3);
    if ($isunknown({mode, dccm_sram_wdata_bitflip, d0, d3})) $display("RESULT X"); else $display("RESULT KNOWN");
    $finish;
  end
endmodule
