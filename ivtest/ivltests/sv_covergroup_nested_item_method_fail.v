class cov_t;
  bit op;
  covergroup cg;
    op_cp: coverpoint op;
  endgroup
  function new;
    cg = new;
  endfunction
endclass

class seq_t;
  cov_t cov;
  function new;
    cov = new;
  endfunction
  function real missing_point;
    return cov.cg.absent_cp.get_coverage();
  endfunction
  function real indexed_point;
    return cov.cg.op_cp[0].get_coverage();
  endfunction
  function real ref_arguments;
    int covered, total;
    return cov.cg.op_cp.get_coverage(covered, total);
  endfunction
  function real bad_receiver;
    return cov.absent_cg.op_cp.get_coverage();
  endfunction
endclass

module top;
  seq_t seq;
  initial begin
    seq = new;
    $display("%f %f %f %f", seq.missing_point(),
      seq.indexed_point(), seq.ref_arguments(), seq.bad_receiver());
  end
endmodule
