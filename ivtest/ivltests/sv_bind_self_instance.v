// IEEE 1800-2017/2023 23.11: binding module a into one selected instance of
// a is finite. Only a definition-wide `bind a a` recursively applies to each
// newly created a instance.
package sv_bind_self_instance_counts;
  int hits;
endpackage

module sv_bind_self_instance_a;
  initial sv_bind_self_instance_counts::hits =
    sv_bind_self_instance_counts::hits + 1;
endmodule

module sv_bind_self_instance;
  sv_bind_self_instance_a u();

  initial begin
    #1;
    if (sv_bind_self_instance_counts::hits == 2)
      $display("PASSED");
    else
      $display("FAILED: hits=%0d", sv_bind_self_instance_counts::hits);
  end
endmodule

bind sv_bind_self_instance.u sv_bind_self_instance_a p();
