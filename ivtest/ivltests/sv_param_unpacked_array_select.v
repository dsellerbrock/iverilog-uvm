// Unpacked ARRAY parameters: elements are stored under their REAL
// declared indices, so descending ([3:0]) and non-zero-based ([1:4])
// declarations select the right element; a variable index selects at
// run time; and a trailing bit/part select applies to the ELEMENT
// (the leading index must not be silently dropped).
module main;

  parameter logic [3:0] AP [0:3] = '{4'b0001, 4'b0010, 4'b0100, 4'b1000};
  parameter logic [3:0] BP [3:0] = '{4'd8, 4'd4, 4'd2, 4'd1};
  parameter logic [3:0] CP [1:4] = '{4'd1, 4'd2, 4'd3, 4'd4};
  // Replication form.
  parameter logic [7:0] RP [0:3] = '{4{8'h5a}};
  // String elements (constant index only).
  parameter string SP [0:1] = '{"aa", "bb"};

  int errors = 0;

  task check_int(input string what, input int got, input int exp);
    if (got !== exp) begin
      errors++;
      $display("FAILED: %0s = %0d, expected %0d", what, got, exp);
    end
  endtask

  initial begin
    // Ascending zero-based control.
    check_int("AP[0]", AP[0], 1);
    check_int("AP[2]", AP[2], 4);

    // Descending: BP[3] is the FIRST pattern element.
    check_int("BP[3]", BP[3], 8);
    check_int("BP[0]", BP[0], 1);

    // Non-zero-based ascending: CP[1] is the first element.
    check_int("CP[1]", CP[1], 1);
    check_int("CP[4]", CP[4], 4);

    // Replication.
    check_int("RP[3]", RP[3], 8'h5a);

    // Variable element index, each declaration direction.
    for (int i = 0; i < 4; i++) begin
      check_int($sformatf("AP[i=%0d]", i), AP[i], 1 << i);
      check_int($sformatf("BP[i=%0d]", i), BP[i], 1 << i);
    end
    for (int i = 1; i <= 4; i++)
      check_int($sformatf("CP[i=%0d]", i), CP[i], i);

    // Trailing selects apply to the ELEMENT: AP[2] is 4'b0100.
    if (AP[2][2] !== 1'b1 || AP[2][1] !== 1'b0) begin
      errors++;
      $display("FAILED: AP[2][2]=%b AP[2][1]=%b, expected 1 0",
               AP[2][2], AP[2][1]);
    end
    if (AP[2][2:1] !== 2'b10) begin
      errors++;
      $display("FAILED: AP[2][2:1]=%b, expected 10", AP[2][2:1]);
    end

    // String elements still resolve by constant index.
    if (SP[1] != "bb") begin
      errors++;
      $display("FAILED: SP[1]=%0s, expected bb", SP[1]);
    end

    // Out-of-range constant index yields x, not a wrong element.
    if (CP[0] === 4'bxxxx) ; else begin
      errors++;
      $display("FAILED: CP[0]=%b, expected xxxx", CP[0]);
    end

    if (errors == 0)
      $display("PASSED");
    else
      $display("FAILED: %0d error(s)", errors);
    $finish(0);
  end
endmodule
