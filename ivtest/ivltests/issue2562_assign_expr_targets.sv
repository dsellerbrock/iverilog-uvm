// IEEE 1800-2017/2023 11.3.6: an assignment expression may have any
// variable l-value; its value is the value assigned to the left-hand side.
module issue2562_assign_expr_targets;
  logic [7:0] arr[4], v, r;
  byte b2[2];
  real rl, rarr[2], rr;
  int i, k;
  bit ok = 1;

  task automatic check(string what, logic [63:0] got, logic [63:0] want);
    if (got !== want) begin
      $display("FAILED %s: %h, expected %h", what, got, want);
      ok = 0;
    end
  endtask

  initial begin
    v = 8'h00;
    r = (arr[1] = 8'd7);
    check("element value", r, 7); check("element store", arr[1], 7);
    i = 2;
    r = (arr[i] = 8'h3c) + 1;
    check("indexed value", r, 8'h3d); check("indexed store", arr[2], 8'h3c);
    r = (v[3:0] = 4'hf);
    check("part-select value", r, 8'h0f); check("part-select store", v, 8'h0f);
    k = 1;
    r = (v[k*4 +: 4] = 4'ha);
    check("indexed part-select", r, 8'h0a); check("indexed ps store", v, 8'haf);
    r = (b2[0] = 8'bx0101010);
    check("2-state value", r, 8'h2a); check("2-state store", b2[0], 8'h2a);
    if (!((rl = 2.5) > 1) || rl != 2.5) begin
      $display("FAILED real: %f", rl); ok = 0;
    end
    rr = (rarr[1] = 0.25) * 4;
    if (rr != 1.0 || rarr[1] != 0.25) begin
      $display("FAILED real element: %f %f", rr, rarr[1]); ok = 0;
    end
    if (ok) $display("PASSED");
  end
endmodule
