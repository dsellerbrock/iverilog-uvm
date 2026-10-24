module sv_force_array_word;
  logic [15:0] mem [0:1];
  logic [15:0] rhs16;
  logic [7:0] high_byte;
  logic [7:0] low_byte;

  task automatic expect_word(input int word,
                             input logic [15:0] expected,
                             input int step);
    if (mem[word] !== expected) begin
      $display("FAILED step=%0d word=%0d actual=%h expected=%h",
               step, word, mem[word], expected);
      $finish;
    end
  endtask

  initial begin
    // A whole unpacked-array word is a standard-legal singular variable.
    mem[1] = 16'h1111;
    rhs16 = 16'hcafe;
    force mem[1] = rhs16;
    #0 expect_word(1, 16'hcafe, 1);
    mem[1] = 16'h2222;
    #0 expect_word(1, 16'hcafe, 2);
    rhs16 = 16'h5678;
    #0 expect_word(1, 16'h5678, 3);
    release mem[1];
    #0 expect_word(1, 16'h5678, 4);

    // A Caliptra-shaped concatenation is structurally lowered to a live
    // source net rather than snapshotted at force activation.
    high_byte = 8'h12;
    low_byte = 8'h34;
    force mem[1] = {high_byte, low_byte};
    #0 expect_word(1, 16'h1234, 5);
    high_byte = 8'hab;
    low_byte = 8'hcd;
    #0 expect_word(1, 16'habcd, 6);
    release mem[1];

    $display("PASSED");
  end
endmodule
