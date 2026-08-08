`begin_keywords "1800-2012"

// Exact reduced forms of the last two Adams-Bridge/Caliptra elaboration
// errors: read a fixed partial-index row procedurally and drive one
// continuously. Keep SHARE=1 and SHARE=2 plus disjoint sibling row drivers.
module main;
  localparam int RPC2 = 2;
  localparam int SHARE2 = 2;
  logic [7:0] datapath2[RPC2:0][SHARE2];
  logic [7:0] storage2[SHARE2];
  logic [7:0] storage_d2[SHARE2];
  logic [7:0] round2[SHARE2];

  localparam int RPC1 = 1;
  localparam int SHARE1 = 1;
  logic [7:0] datapath1[RPC1:0][SHARE1];
  logic [7:0] storage1[SHARE1];
  logic [7:0] storage_d1[SHARE1];

  // Compact interaction guard: both fixed prefixes have nonzero canonical
  // bases and the residual dimensions run in opposite directions.
  logic [7:0] reverse_src[1:0][1:0];
  logic [7:0] reverse_dst[1:0][0:1];

  always_comb begin
    storage_d2 = datapath2[RPC2];
    storage_d1 = datapath1[RPC1];
    reverse_dst[1] = reverse_src[1];
  end

  assign datapath2[0] = storage2;
  assign datapath2[1] = round2;
  assign datapath1[0] = storage1;

  (* ivl_synthesis_off *)
  initial begin
    datapath2[RPC2][0] = 8'hA0;
    datapath2[RPC2][1] = 8'hA1;
    storage2[0] = 8'hB0;
    storage2[1] = 8'hB1;
    round2[0] = 8'hC0;
    round2[1] = 8'hC1;
    datapath1[RPC1][0] = 8'hD0;
    storage1[0] = 8'hE0;
    reverse_src[1][1] = 8'hF1;
    reverse_src[1][0] = 8'hF0;

    #1;
    if (storage_d2[0] !== 8'hA0 || storage_d2[1] !== 8'hA1 ||
        datapath2[0][0] !== 8'hB0 || datapath2[0][1] !== 8'hB1 ||
        datapath2[1][0] !== 8'hC0 || datapath2[1][1] !== 8'hC1 ||
        storage_d1[0] !== 8'hD0 || datapath1[0][0] !== 8'hE0 ||
        reverse_dst[1][0] !== 8'hF1 || reverse_dst[1][1] !== 8'hF0) begin
      $display("FAILED -- Caliptra partial-index subarray shape");
      $finish;
    end

    datapath2[RPC2][1] = 8'hA2;
    datapath1[RPC1][0] = 8'hD1;
    #1;
    if (storage_d2[1] !== 8'hA2 || storage_d1[0] !== 8'hD1) begin
      $display("FAILED -- partial-index source sensitivity");
      $finish;
    end

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
