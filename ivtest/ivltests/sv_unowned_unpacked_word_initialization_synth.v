module unowned_unpacked_word_initialization(
  input  logic       clk,
  input  logic [7:0] logic_data,
  input  bit   [7:0] bit_data,
  output logic [7:0] logic0,
  output logic [7:0] logic1,
  output logic [7:0] logic2,
  output bit   [7:0] bit0,
  output bit   [7:0] bit1,
  output bit   [7:0] bit2
);
  logic [7:0] logic_mem [0:2];
  bit   [7:0] bit_mem   [0:2];

  always_ff @(posedge clk) begin
    logic_mem[2] <= logic_data;
    bit_mem[1] <= bit_data;
  end

  assign logic0 = logic_mem[0];
  assign logic1 = logic_mem[1];
  assign logic2 = logic_mem[2];
  assign bit0 = bit_mem[0];
  assign bit1 = bit_mem[1];
  assign bit2 = bit_mem[2];
endmodule

module tb_unowned_unpacked_word_initialization;
  logic clk = 0;
  logic [7:0] logic_data = 8'ha5;
  bit   [7:0] bit_data = 8'h3c;
  logic [7:0] logic0, logic1, logic2;
  bit   [7:0] bit0, bit1, bit2;

  unowned_unpacked_word_initialization dut(.*);

  task tick;
    #1 clk = 1;
    #1 clk = 0;
  endtask

  initial begin
    #1;
    if (logic0 !== 8'hxx || logic1 !== 8'hxx || logic2 !== 8'hxx
        || bit0 !== 8'h00 || bit1 !== 8'h00 || bit2 !== 8'h00)
      $fatal(1, "initial logic=%h,%h,%h bit=%h,%h,%h",
             logic0, logic1, logic2, bit0, bit1, bit2);

    tick();
    if (logic0 !== 8'hxx || logic1 !== 8'hxx || logic2 !== 8'ha5
        || bit0 !== 8'h00 || bit1 !== 8'h3c || bit2 !== 8'h00)
      $fatal(1, "first write logic=%h,%h,%h bit=%h,%h,%h",
             logic0, logic1, logic2, bit0, bit1, bit2);

    logic_data = 8'h5a;
    bit_data = 8'hc3;
    tick();
    if (logic0 !== 8'hxx || logic1 !== 8'hxx || logic2 !== 8'h5a
        || bit0 !== 8'h00 || bit1 !== 8'hc3 || bit2 !== 8'h00)
      $fatal(1, "second write logic=%h,%h,%h bit=%h,%h,%h",
             logic0, logic1, logic2, bit0, bit1, bit2);

    $display("PASS");
    $finish(0);
  end
endmodule
