`begin_keywords "1800-2012"

module main;
  localparam int unsigned N = 4;

  logic clk;
  logic [15:0] whole_source [N];
  logic [15:0] whole_result [N];
  logic [15:0] loop_source [N];
  logic [15:0] loop_result [N];

  logic        memory_write;
  logic [1:0]  memory_address;
  logic [15:0] memory_data;
  logic [15:0] memory [N];

  // Caliptra csrng_state_db uses this whole-unpacked-array nonblocking copy.
  // Elaboration represents it as a procedural loop over the array words.
  always_ff @(posedge clk)
    whole_result <= whole_source;

  // Also pin the source-level form: every static iteration is a distinct
  // flip-flop update, even though the elaborated word expression is not an
  // ordinary constant until synthesis substitutes the loop index.
  always_ff @(posedge clk) begin
    for (int word = 0; word < N; word++)
      loop_result[word] <= loop_source[word] ^ (16'h0101 * word);
  end

  // Control case: a genuine single run-time-selected word remains eligible
  // for the compact structural array write port.
  always_ff @(posedge clk) begin
    if (memory_write)
      memory[memory_address] <= memory_data;
  end

  task automatic tick;
    #1 clk = 1'b1;
    #1 clk = 1'b0;
  endtask

  task automatic check_results(input string label);
    for (int word = 0; word < N; word++) begin
      if (whole_result[word] !== whole_source[word]) begin
        $display("FAILED -- %s whole[%0d]=%h expected=%h",
                 label, word, whole_result[word], whole_source[word]);
        $finish;
      end
      if (loop_result[word] !==
          (loop_source[word] ^ (16'h0101 * word))) begin
        $display("FAILED -- %s loop[%0d]=%h source=%h",
                 label, word, loop_result[word], loop_source[word]);
        $finish;
      end
    end
  endtask

  (* ivl_synthesis_off *)
  initial begin
    clk = 1'b0;
    memory_write = 1'b0;
    memory_address = 2'b00;
    memory_data = 16'h0000;
    for (int word = 0; word < N; word++) begin
      whole_source[word] = 16'h1200 + word;
      loop_source[word] = 16'h3400 + word;
    end
    tick();
    check_results("first copy");

    for (int word = 0; word < N; word++) begin
      whole_source[word] = 16'ha500 + word;
      loop_source[word] = 16'h5a00 + word;
    end
    memory_write = 1'b1;
    memory_address = 2'd2;
    memory_data = 16'hc0de;
    tick();
    check_results("second copy");
    if (memory[2] !== 16'hc0de) begin
      $display("FAILED -- compact memory write=%h expected=c0de", memory[2]);
      $finish;
    end

    $display("PASSED");
    $finish;
  end
endmodule

`end_keywords
