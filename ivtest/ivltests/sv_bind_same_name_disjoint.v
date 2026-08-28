// IEEE 1800-2017/2023 23.11: the bound instance name belongs to the selected
// target scope. The same name in two disjoint target scopes is legal.
package sv_bind_same_name_disjoint_counts;
  int hits;
endpackage

module sv_bind_same_name_disjoint_probe;
  initial sv_bind_same_name_disjoint_counts::hits =
    sv_bind_same_name_disjoint_counts::hits + 1;
endmodule

module sv_bind_same_name_disjoint_leaf;
endmodule

module sv_bind_same_name_disjoint;
  sv_bind_same_name_disjoint_leaf a();
  sv_bind_same_name_disjoint_leaf b();

  initial begin
    #1;
    if (sv_bind_same_name_disjoint_counts::hits == 2)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d", sv_bind_same_name_disjoint_counts::hits);
  end
endmodule

bind sv_bind_same_name_disjoint.a sv_bind_same_name_disjoint_probe bp();
bind sv_bind_same_name_disjoint.b sv_bind_same_name_disjoint_probe bp();
