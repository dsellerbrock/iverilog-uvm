module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  logic s = 1'b0; logic [3:0] v = 4'b0000; logic a = 0, b = 0;
  int np, nn, ne, na, nvp, nva, nres;
  always @(posedge s) np++;
  always @(negedge s) nn++;
  always @(edge s) ne++;
  always @(s) na++;
  always @(posedge v) nvp++;
  always @(v) nva++;
  always @(a & b) nres++;
  initial begin
    #1 s = 1; #1 s = 1'bx; #1 s = 1; #1 s = 1'bz; #1 s = 1; #1 s = 0; #1 s = 1'bx; #1 s = 0;
    #1 s = 1'bz; #1 s = 0; #1 s = 1'bx; #1 s = 1'bz; #1 s = 1'bx; #1 s = 1; #1;
    chk("9.4.2.posedge_table9_2", np == 7);
    chk("9.4.2.negedge_table9_2", nn == 5);
    chk("9.4.2.edge_is_pos_or_neg", ne == 12);
    chk("9.4.2.implicit_event_any_change", na == 14);
    #1 v = 4'b0010; #1 v = 4'b0011; #1 v = 4'b0111; #1 v = 4'b0110; #1;
    chk("9.4.2.edge_only_on_lsb", nvp == 1);
    chk("9.4.2.implicit_event_vector_any_bit", nva == 4);
    #1 a = 1; #1 b = 1; #1 a = 0; #1;
    chk("9.4.2.operand_change_without_result_change_not_event", nres == 2);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
