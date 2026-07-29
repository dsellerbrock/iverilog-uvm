// IEEE 1800-2017 11.5.2 / 7.4.6: an index into a packed array may be a
// run-time expression in ANY dimension, not just the last one.
//
// Only the FINAL index could be variable. `t[i][j]' with a variable i was
//   error: A reference to a net or variable (`i') is not allowed in a
//          constant expression.
// because the leading indices were folded into a single CONSTANT slice
// offset. `t[1][j]' (constant prefix) worked, `t[i][1]' and `t[i][j]' did
// not, in both l-value and r-value position.
//
// This is the transpose idiom in OpenTitan's aes_pkg (`aes_transpose'),
// so it blocked AES and KMAC.
//
// The test checks VALUES, not just that it compiles: a wrong offset
// scaling would still elaborate but read the wrong element.

module sv_packed_multidim_var_index;

  logic [3:0][3:0][7:0] a, b;
  logic [3:0][3:0][7:0] w;

  int errors = 0;

  // The aes_pkg shape: both indices variable, both sides of the assignment.
  function automatic logic [3:0][3:0][7:0] transpose_f(logic [3:0][3:0][7:0] in);
    logic [3:0][3:0][7:0] t;
    t = '0;
    for (int j = 0; j < 4; j++)
      for (int i = 0; i < 4; i++)
        t[i][j] = in[j][i];
    return t;
  endfunction

  initial begin
    // Fill through a VARIABLE-index l-value.
    for (int r = 0; r < 4; r++)
      for (int c = 0; c < 4; c++)
        a[r][c] = 8'(r*16 + c);

    // Read back through a VARIABLE-index r-value.
    for (int r = 0; r < 4; r++)
      for (int c = 0; c < 4; c++)
        if (a[r][c] !== 8'(r*16 + c)) begin
          $display("FAILED -- a[%0d][%0d] = %h, want %h", r, c, a[r][c], 8'(r*16+c));
          errors++;
        end

    // Variable OUTER index with a constant inner one -- the case the old
    // prefix-folding path could not express at all.
    for (int r = 0; r < 4; r++)
      if (a[r][2] !== 8'(r*16 + 2)) begin
        $display("FAILED -- a[%0d][2] = %h, want %h", r, a[r][2], 8'(r*16+2));
        errors++;
      end

    // A partial select (one index of a two-dimensional array) must still
    // address the whole row.
    for (int r = 0; r < 4; r++)
      if (a[r] !== {8'(r*16+3), 8'(r*16+2), 8'(r*16+1), 8'(r*16+0)}) begin
        $display("FAILED -- a[%0d] row = %h", r, a[r]);
        errors++;
      end

    // The function form, and transpose-twice as an identity check.
    b = transpose_f(a);
    for (int r = 0; r < 4; r++)
      for (int c = 0; c < 4; c++)
        if (b[r][c] !== a[c][r]) begin
          $display("FAILED -- transpose b[%0d][%0d] = %h, want %h",
                   r, c, b[r][c], a[c][r]);
          errors++;
        end
    if (transpose_f(b) !== a) begin
      $display("FAILED -- transposing twice did not return the original");
      errors++;
    end

    // Constant indices must be unaffected.
    w = '0;
    w[2][1] = 8'hC3;
    if (w[2][1] !== 8'hC3) begin
      $display("FAILED -- constant index w[2][1] = %h, want c3", w[2][1]);
      errors++;
    end
    if (w[2][0] !== 8'h00 || w[3][1] !== 8'h00) begin
      $display("FAILED -- constant index write bled into a neighbour");
      errors++;
    end

    if (errors == 0) $display("PASSED");
    $finish(0);
  end

endmodule
