// IEEE 1800-2017 14.16 and 10.4.2: selected packed clocking-output drives
// retain clocking scheduling for same-scope and static hierarchical names.
`timescale 1ns/1ps

module selected_output_receiver(input logic clk);
  typedef struct packed {
    logic [3:0] hi;
    logic [3:0] lo;
  } bus_t;

  bus_t raw;
  wire bus_t bus;
  logic [0:7] ascending_raw;
  wire [0:7] ascending;
  integer failures = 0;

  clocking cb @(posedge clk);
    output bus = raw;
    output ascending = ascending_raw;
  endclocking

  initial begin
    raw = 8'hA5;
    ascending_raw = '0;
    #2 cb.bus.lo <= 4'hC;
    #1;
    if (raw !== 8'hA5) begin
      failures++;
      $display("FAILED same-scope selected drive landed early raw=%h", raw);
    end
    #3;
    if (raw !== 8'hAC) begin
      failures++;
      $display("FAILED same-scope selected drive raw=%h expected=ac", raw);
    end
  end
endmodule

module sv_clocking_selected_output_static;
  logic clk = 1'b0;
  integer failures = 0;

  always #5 clk = ~clk;

  generate
    for (genvar idx = 0; idx < 1; idx++) begin : g
      selected_output_receiver u(clk);
    end
  endgenerate

  task check(input logic [7:0] expected, input string label_text);
    if (g[0].u.raw !== expected) begin
      failures++;
      $display("FAILED %s raw=%h expected=%h", label_text, g[0].u.raw,
               expected);
    end
  endtask

  initial begin
    #8;
    g[0].u.cb.bus[5:4] <= 2'b00;
    #1;
    check(8'hAC, "static selected drive landed early");
    #7;
    check(8'h8C, "static selected buffered drive");

    fork
      begin
        @(g[0].u.cb);
        g[0].u.cb.bus.lo <= 4'h3;
      end
    join_none
    #10;
    check(8'h83, "static selected current-event drive");

    // Disjoint buffered/current-event selections merge at one event.
    #2;
    g[0].u.cb.bus.lo <= 4'h5;
    fork
      begin
        @(g[0].u.cb);
        g[0].u.cb.bus.hi <= 4'hE;
      end
    join_none
    #8;
    check(8'hE5, "disjoint static selected drives merge");

    // A current-event drive to the same selection supersedes the older
    // buffered value that matures at that event.
    #2;
    g[0].u.cb.bus.lo <= 4'h1;
    fork
      begin
        @(g[0].u.cb);
        g[0].u.cb.bus.lo <= 4'h2;
      end
    join_none
    #8;
    check(8'hE2, "same-selection current drive wins");

    // A normal NBA to an untouched sibling in the edge slot survives the
    // selected clocking drive's later per-bit update.
    #2;
    g[0].u.cb.bus.lo <= 4'h4;
    fork
      begin
        @(posedge clk);
        g[0].u.raw.hi <= 4'hA;
      end
    join_none
    #8;
    check(8'hA4, "ordinary sibling NBA survives");

    // Pin a single-bit destination, then both indexed part-select forms.
    #2;
    g[0].u.cb.bus[7] <= 1'b0;
    #8;
    check(8'h24, "static single-bit output drive");

    #2;
    g[0].u.cb.bus[2 +: 2] <= 2'b11;
    #8;
    check(8'h2C, "static indexed plus output drive");

    // Canonical offsets must also respect an ascending packed declaration.
    #2;
    g[0].u.cb.ascending[2 +: 3] <= 3'b101;
    #8;
    if (g[0].u.ascending_raw[2] !== 1'b1
        || g[0].u.ascending_raw[3] !== 1'b0
        || g[0].u.ascending_raw[4] !== 1'b1) begin
      failures++;
      $display("FAILED ascending indexed plus raw=%b",
               g[0].u.ascending_raw);
    end

    #2;
    g[0].u.cb.ascending[5 -: 2] <= 2'b11;
    #8;
    if (g[0].u.ascending_raw[5] !== 1'b1
        || g[0].u.ascending_raw[4] !== 1'b1) begin
      failures++;
      $display("FAILED ascending indexed minus raw=%b",
               g[0].u.ascending_raw);
    end

    failures += g[0].u.failures;
    if (failures != 0)
      $fatal(1, "%0d selected static clocking checks failed", failures);
    $display("PASSED");
    $finish;
  end
endmodule
