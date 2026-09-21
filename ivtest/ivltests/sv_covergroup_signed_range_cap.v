module test;
  covergroup cg with function sample(int value);
    option.per_instance = 1;
    cp: coverpoint value {
      bins huge[] = {[32'sh8000_0000:32'sh7fff_ffff]};
    }
  endgroup
  covergroup fixed_cg with function sample(int value);
    cp: coverpoint value { bins huge_fixed[65537] = {[0:65536]}; }
  endgroup
  fixed_cg fixed_instance;
  cg c;
  initial begin
    c = new;
    fixed_instance = new;
    $display("CAP_CONTROL");
  end
endmodule
