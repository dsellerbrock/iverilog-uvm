package issue3381_first;
  covergroup cg with function sample(bit x);
    cp: coverpoint x;
  endgroup
endpackage

package issue3381_second;
  covergroup cg with function sample(bit x);
    cp: coverpoint x { bins one = {1}; }
  endgroup
endpackage

module issue3381_package_covergroup;
  issue3381_first::cg a = new;
  issue3381_second::cg b = new;
  initial begin
    a.sample(1);
    b.sample(1);
    if (a.get_inst_coverage() != 50.0 || b.get_inst_coverage() != 100.0)
      $fatal(1, "incorrect package covergroup coverage: %f %f",
             a.get_inst_coverage(), b.get_inst_coverage());
    $display("PASS");
  end
endmodule
