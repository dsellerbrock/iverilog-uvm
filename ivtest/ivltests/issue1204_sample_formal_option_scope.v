package issue1204_option_pkg;
  localparam int x = 3;
endpackage

module issue1204_sample_formal_option_scope;
  covergroup cg with function sample(int x);
    option.weight = issue1204_option_pkg::x;
    type_option.weight = int'(1);
    cp: coverpoint x;
  endgroup

  cg c = new;
  initial begin
    c.sample(3);
    $display("PASSED");
  end
endmodule
