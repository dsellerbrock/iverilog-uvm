module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  logic a = 0, b = 0, c = 0, d = 0, e = 0, clk = 0, rstn = 1, en = 0, q = 0;
  int n_or, n_comma, n_pn, n_mix, n_iff, n_iffor;
  always @(a or b) n_or++;
  always @(c, d, e) n_comma++;
  always @(posedge clk, negedge rstn) n_pn++;
  always @(a or b, c, d or e) n_mix++;
  always @(q iff en) n_iff++;
  always @(q iff en or b) n_iffor++;
  initial begin
    #1 a = 1; #1 b = 1; #1;
    chk("9.4.2.1.or_either", n_or == 2);
    #1 c = 1; #1 d = 1; #1 e = 1; #1;
    chk("9.4.2.1.comma_is_or", n_comma == 3);
    #1 clk = 1; #1 clk = 0; #1 rstn = 0; #1 rstn = 1; #1;
    chk("9.4.2.1.edge_list_with_comma", n_pn == 2);
    chk("9.4.2.1.mixed_or_and_comma", n_mix == 5);
    #1 q = 1; #1 en = 1; #1 q = 0; #1;
    chk("9.4.2.3.iff_false_blocks_and_enable_alone_no_event", n_iff == 1);
    #1 en = 0; #1 b = 0; #1;
    chk("9.4.2.3.iff_has_precedence_over_or", n_iffor == 3);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
