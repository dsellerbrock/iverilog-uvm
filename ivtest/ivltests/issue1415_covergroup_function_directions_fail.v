function automatic int from_ref(ref int value); return value; endfunction
function automatic int from_output(output int value); value = 1; return value; endfunction
function automatic int from_inout(inout int value); return value; endfunction

module issue1415_covergroup_function_directions_fail;
  covergroup bad_cg(int limit);
    ref_bin: coverpoint limit { bins forbidden = {from_ref(limit)}; }
    output_bin: coverpoint limit { bins forbidden = {from_output(limit)}; }
    inout_bin: coverpoint limit { bins forbidden = {from_inout(limit)}; }
  endgroup

  bad_cg cg;
  initial begin
    cg = new(1);
    cg.sample();
  end
endmodule
