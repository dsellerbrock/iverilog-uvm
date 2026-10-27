module top;
  int fails = 0;
  task automatic chk(string id, bit ok);
    if (ok) $display("PASS %s", id); else begin $display("FAIL %s", id); fails++; end
  endtask
  logic [3:0] a = 0, b = 0, c = 0, d = 0, f = 0, ai = 0, y, kid, ii = 0, bb = 0;
  logic en = 0;
  logic [7:0] y8;
  int ny, n8, nk;
  function automatic logic [3:0] myfunction(logic [3:0] x); return x + 1; endfunction
  always @* begin ny++; y = (a & b) | (c & d) | myfunction(f); end
  always @* begin n8++; y8 = 8'hff; y8[ai] = !en; end
  always @* begin nk++; @(ii) kid = bb; end
  initial begin
    #1 a = 1; #1 b = 1; #1 c = 1; #1 d = 1; #1 f = 1; #1;
    chk("9.4.2.2.star_includes_all_operands_and_function_args", ny == 5);
    #1 ai = 3; #1 en = 1; #1;
    chk("9.4.2.2.star_index_and_rhs_not_lvalue_base", n8 == 2 && y8[3] == 1'b0);
    #1 ii = 2; #1;
    chk("9.4.2.2.star_excludes_ids_only_in_event_expr", nk == 0);
    #1 bb = 5; #1;
    chk("9.4.2.2.star_wakes_on_rhs_id", nk == 1 && kid == 0);
    #1 ii = 3; #1;
    chk("9.4.2.2.inner_event_then_assign", kid == 5);
    $display("DONE fails=%0d", fails); $finish;
  end
endmodule
