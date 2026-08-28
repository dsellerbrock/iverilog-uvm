// IEEE 1800-2017/2023 23.11/27.4: each elaborated loop-generate occurrence
// evaluates its relative bind target select in that occurrence's genvar scope.
package sv_bind_owner_loop_genvar_select_counts;
  int hits;
  int sum;
endpackage

module sv_bind_owner_loop_genvar_select_probe(input int observed);
  initial begin
    sv_bind_owner_loop_genvar_select_counts::hits =
      sv_bind_owner_loop_genvar_select_counts::hits + 1;
    sv_bind_owner_loop_genvar_select_counts::sum =
      sv_bind_owner_loop_genvar_select_counts::sum + observed;
  end
endmodule

module sv_bind_owner_loop_genvar_select_leaf #(parameter int TAG = 0);
endmodule

module sv_bind_owner_loop_genvar_select_holder;
  sv_bind_owner_loop_genvar_select_leaf #(.TAG(10)) children[0:1]();

  for (genvar i = 0; i < 2; i++) begin : owner
    bind children[i] sv_bind_owner_loop_genvar_select_probe bp(.observed(TAG));
  end
endmodule

module sv_bind_owner_loop_genvar_select;
  sv_bind_owner_loop_genvar_select_holder holder();

  initial begin
    #1;
    if (sv_bind_owner_loop_genvar_select_counts::hits == 2
        && sv_bind_owner_loop_genvar_select_counts::sum == 20)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d sum=%0d",
               sv_bind_owner_loop_genvar_select_counts::hits,
               sv_bind_owner_loop_genvar_select_counts::sum);
  end
endmodule
