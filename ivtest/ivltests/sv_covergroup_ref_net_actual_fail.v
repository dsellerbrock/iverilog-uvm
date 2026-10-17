module sv_covergroup_ref_net_actual_fail;
  wire logic [1:0] vector_net;

  covergroup vector_cg(ref logic [1:0] value);
    cp: coverpoint value;
  endgroup

  covergroup scalar_cg(ref logic value);
    cp: coverpoint value;
  endgroup

  vector_cg vector_instance;
  scalar_cg select_instance;

  initial begin
    vector_instance = new(vector_net);
    select_instance = new(vector_net[0]);
  end
endmodule
