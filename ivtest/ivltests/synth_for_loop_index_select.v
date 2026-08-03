`begin_keywords "1800-2012"

module main;
  localparam int unsigned EventBase = 3;

  logic [31:0]       source;
  logic [31:0][31:0] events;

  // Ibex initializes a packed event matrix, then uses the procedural loop
  // index in both an element select and an arithmetic bit-select base. During
  // synthesis every loop iteration has a constant index and must lower to
  // fixed selects instead of accumulating dynamic-select hardware.
  always_comb begin
    events = '0;
    for (int i = 0; i < 32; i++) begin
      if (i >= EventBase)
        events[i][i - EventBase] = source[i];
    end
  end

  task automatic fail(input string label);
    $display("FAILED -- %s source=%h events=%h", label, source, events);
    $finish;
  endtask

  (* ivl_synthesis_off *)
  initial begin
    source = 32'hffff_ffff;
    #1;
    for (int i = 0; i < 32; i++) begin
      for (int j = 0; j < 32; j++) begin
        if (events[i][j] !== ((i >= EventBase) && (j == i - EventBase)))
          fail("all-one source");
      end
    end

    source = 32'ha5a5_5a5a;
    #1;
    for (int i = 0; i < 32; i++) begin
      for (int j = 0; j < 32; j++) begin
        if (events[i][j] !==
            (((i >= EventBase) && (j == i - EventBase)) ? source[i] : 1'b0))
          fail("pattern source");
      end
    end

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
