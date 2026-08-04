`begin_keywords "1800-2012"

module main #(
  parameter int unsigned Depth = 1024
);

  logic                  clk;
  logic                  req;
  logic                  write;
  logic                  grant;
  logic [$clog2(Depth)-1:0] addr;
  logic [7:0]            wdata;
  logic [7:0]            rdata;
  logic [7:0]            mem [0:Depth-1];

  // Keep this memory large enough to exercise output-set collection for
  // every possible run-time-selected word.  The nested conditions model the
  // request/write/grant qualification used by single-port SRAM wrappers.
  always_ff @(posedge clk) begin
    if (req) begin
      if (write) begin
        if (grant)
          mem[addr] <= wdata;
      end else begin
        if (grant)
          rdata <= mem[addr];
      end
    end
  end

  task automatic tick;
    #1 clk = 1'b1;
    #1 clk = 1'b0;
  endtask

  task automatic write_word(input logic [$clog2(Depth)-1:0] index,
                            input logic [7:0] value);
    req = 1'b1;
    write = 1'b1;
    grant = 1'b1;
    addr = index;
    wdata = value;
    tick();
  endtask

  task automatic read_word(input logic [$clog2(Depth)-1:0] index,
                           input logic [7:0] expected);
    req = 1'b1;
    write = 1'b0;
    grant = 1'b1;
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
    grant = 1'b0;
    addr = '0;
    wdata = '0;

    write_word(10'd0, 8'h12);
    write_word(10'd511, 8'h5a);
    write_word(10'd1023, 8'ha5);
    read_word(10'd0, 8'h12);
    read_word(10'd511, 8'h5a);
    read_word(10'd1023, 8'ha5);

    // Both outer request gating and the innermost grant gating must suppress
    // the decoded write to every word.
    req = 1'b0;
    write = 1'b1;
    grant = 1'b1;
    addr = 10'd511;
    wdata = 8'h00;
    tick();
    req = 1'b1;
    grant = 1'b0;
    tick();
    read_word(10'd511, 8'h5a);

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
