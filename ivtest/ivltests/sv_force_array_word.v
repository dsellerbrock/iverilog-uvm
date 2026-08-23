module sv_force_array_word;
  logic [15:0] mem [0:1];
  logic [7:0] rhs;
  logic [15:0] rhs16;
  logic [7:0] high_byte;
  logic [7:0] low_byte;
  logic [31:0] wide_rhs;

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
    // Packed part-select compatibility extension on a compact variable word.
    mem[0] = 16'h1234;
    rhs = 8'ha5;
    force mem[0][11:4] = rhs;
    #0 expect_word(0, 16'h1a54, 1);

    // A procedural write updates the driven value while forced bits remain
    // visible, and a source change continuously updates the forced slice.
    mem[0] = 16'hdead;
    #0 expect_word(0, 16'hda5d, 2);
    rhs = 8'h3c;
    #0 expect_word(0, 16'hd3cd, 3);

    // Variable release holds the last forced value until the next write.
    release mem[0][11:4];
    #0 expect_word(0, 16'hd3cd, 4);
    mem[0] = 16'hbeef;
    #0 expect_word(0, 16'hbeef, 5);

    // A whole unpacked-array word is a standard-legal singular variable.
    mem[1] = 16'h1111;
    rhs16 = 16'hcafe;
    force mem[1] = rhs16;
    #0 expect_word(1, 16'hcafe, 6);
    mem[1] = 16'h2222;
    #0 expect_word(1, 16'hcafe, 7);
    rhs16 = 16'h5678;
    #0 expect_word(1, 16'h5678, 8);
    release mem[1];
    #0 expect_word(1, 16'h5678, 9);

    // A Caliptra-shaped concatenation is structurally lowered to a live
    // source net rather than snapshotted at force activation.
    high_byte = 8'h12;
    low_byte = 8'h34;
    force mem[1] = {high_byte, low_byte};
    #0 expect_word(1, 16'h1234, 10);
    high_byte = 8'hab;
    low_byte = 8'hcd;
    #0 expect_word(1, 16'habcd, 11);
    release mem[1];

    // Newer overlapping forces permanently supersede only their overlap.
    // Releasing the newer force must not resurrect the older source there.
    mem[0] = 16'h0000;
    rhs = 8'ha5;
    high_byte = 8'h3c;
    force mem[0][7:0] = rhs;
    force mem[0][11:4] = high_byte;
    #0 expect_word(0, 16'h03c5, 12);
    rhs = 8'hf2;
    #0 expect_word(0, 16'h03c2, 13);
    high_byte = 8'h96;
    #0 expect_word(0, 16'h0962, 14);

    release mem[0][11:8];
    high_byte = 8'h47;
    #0 expect_word(0, 16'h0972, 15);
    release mem[0][7:4];
    rhs = 8'h0f;
    high_byte = 8'he1;
    #0 expect_word(0, 16'h097f, 16);
    release mem[0][3:0];
    #0 expect_word(0, 16'h097f, 17);
    mem[0] = 16'h4321;
    #0 expect_word(0, 16'h4321, 18);

    // A wide direct signal exercises the force adapter's partial-update
    // cache. Writes outside its linked low byte are invisible; writes inside
    // that byte update only the corresponding forced destination bits.
    mem[0] = 16'haa00;
    wide_rhs = 32'hdead_beef;
    force mem[0][7:0] = wide_rhs;
    #0 expect_word(0, 16'haaef, 19);
    wide_rhs[31:16] = 16'h1234;
    #0 expect_word(0, 16'haaef, 20);
    wide_rhs[3:0] = 4'h5;
    #0 expect_word(0, 16'haae5, 21);
    wide_rhs[15:8] = 8'h00;
    #0 expect_word(0, 16'haae5, 22);
    wide_rhs[7:4] = 4'h9;
    #0 expect_word(0, 16'haa95, 23);
    release mem[0][7:0];
    wide_rhs[3:0] = 4'h1;
    #0 expect_word(0, 16'haa95, 24);

    $display("PASSED");
  end
endmodule
