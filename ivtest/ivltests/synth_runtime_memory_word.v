`begin_keywords "1800-2012"

module main;
  logic       clk;
  logic       req;
  logic       write;
  logic [1:0] addr;
  logic [7:0] wdata;
  logic [7:0] rdata;
  logic [7:0] mem [3];

  // OpenTitan prim_ram_1p uses this shape: a run-time-selected whole-word
  // write and a synchronous read share one request-qualified process.
  always_ff @(posedge clk) begin
    if (req) begin
      if (write)
        mem[addr] <= wdata;
      else
        rdata <= mem[addr];
    end
  end

  task automatic tick;
    #1 clk = 1'b1;
    #1 clk = 1'b0;
  endtask

  task automatic write_word(input logic [1:0] index,
                            input logic [7:0] value);
    req = 1'b1;
    write = 1'b1;
    addr = index;
    wdata = value;
    tick();
  endtask

  task automatic read_word(input logic [1:0] index,
                           input logic [7:0] expected);
    req = 1'b1;
    write = 1'b0;
    addr = index;
    tick();
    if (rdata !== expected) begin
      $display("FAILED -- read mem[%0d]=%h expected=%h",
               index, rdata, expected);
      $finish;
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    clk = 1'b0;
    req = 1'b0;
    write = 1'b0;
    addr = 2'b00;
    wdata = 8'h00;

    write_word(2'd0, 8'h12);
    write_word(2'd1, 8'h34);
    write_word(2'd2, 8'h56);
    read_word(2'd0, 8'h12);
    read_word(2'd1, 8'h34);
    read_word(2'd2, 8'h56);

    write_word(2'd1, 8'ha5);
    read_word(2'd0, 8'h12);
    read_word(2'd1, 8'ha5);
    read_word(2'd2, 8'h56);

    // The declared depth is three, so address three selects no word.
    write_word(2'd3, 8'hff);
    read_word(2'd0, 8'h12);
    read_word(2'd1, 8'ha5);
    read_word(2'd2, 8'h56);

    // A four-state unknown l-value index also selects no word.
    req = 1'b1;
    write = 1'b1;
    addr = 2'bx;
    wdata = 8'hee;
    tick();
    read_word(2'd0, 8'h12);
    read_word(2'd1, 8'ha5);
    read_word(2'd2, 8'h56);

    // A false outer request must suppress every decoded word enable.
    req = 1'b0;
    write = 1'b1;
    addr = 2'd0;
    wdata = 8'h00;
    tick();
    read_word(2'd0, 8'h12);

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
