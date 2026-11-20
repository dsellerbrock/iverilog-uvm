module issue3897_force_vector;
  logic [7:0] source;
  wire [7:0] result = 8'h00;
  logic [3:0] feedback;
  event reactivate;

  logic [7:0] init_source;
  wire [7:0] init_result;
  logic init_done = initialize_force();

  function automatic logic initialize_force();
    init_source = 8'h0f;
    force init_result = init_source + 8'h01;
    init_source = 8'h1f;
    return 1;
  endfunction

  task automatic activate;
    force result = source + 8'h01;
  endtask

  task automatic check(input logic [7:0] expected);
    if (result !== expected)
      $fatal(1, "result = %h, expected %h", result, expected);
  endtask

  always @(reactivate) begin
    release result;
    source = 8'h40;
    activate();
    check(8'h41);
  end

  initial begin
    source = 8'h10;
    activate();
    check(8'h11);
    source = 8'h20;
    #0 check(8'h21);
    if (!init_done || init_result !== 8'h20)
      $fatal(1, "force activated during static initialization = %h", init_result);
    release init_result;
    #1;

    // The source wake precedes the reactivation wake in this slot.
    source = 8'h30;
    -> reactivate;
    #0 check(8'h41);

    // Return to the value published before the previous release.
    source = 8'h20;
    #0 check(8'h21);
    release result;
    check(8'h00);

    // Each publication must be able to wake its own RHS probe.
    feedback = 0;
    begin : activation
      force feedback = feedback < 4'd3 ? feedback + 4'd1 : feedback;
      if (feedback !== 4'd1) $fatal(1, "initial feedback = %h", feedback);
      disable activation;
    end
    #0;
    if (feedback !== 4'd3) $fatal(1, "settled feedback = %h", feedback);
    release feedback;
    $display("PASSED");
  end
endmodule
