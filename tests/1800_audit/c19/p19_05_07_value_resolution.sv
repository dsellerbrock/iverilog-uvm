module p19_05_07_value_resolution;
  bit [2:0] p1;
  bit signed [2:0] p2;
  logic [2:0] p3;

  covergroup cg_unsigned;
    coverpoint p1 {
      bins b1 = {1, [2:5], [6:10]};
      bins b2 = {-1, [1:10], 15};
    }
  endgroup

  covergroup cg_signed;
    coverpoint p2 {
      bins b3 = {1, [2:5], [6:10]};
      bins b4 = {-1, [1:10], 15};
    }
  endgroup

  covergroup cg_wildcard;
    coverpoint p3 {
      bins xz = {3'b0x1};
      wildcard bins xz_wild = {3'b0x1};
    }
  endgroup

  cg_unsigned unsigned_cg = new;
  cg_signed signed_cg = new;
  cg_wildcard wildcard_cg = new;
  int unsigned_num, unsigned_den, signed_num, signed_den, wildcard_num, wildcard_den;
  real unsigned_cov, signed_cov, wildcard_cov;

  initial begin
    for (int i = 0; i < 8; i++) begin
      p1 = i;
      unsigned_cg.sample();
      p2 = i;
      signed_cg.sample();
    end
    p3 = 3'b001;
    wildcard_cg.sample();
    p3 = 3'b011;
    wildcard_cg.sample();

    unsigned_cov = unsigned_cg.get_inst_coverage(unsigned_num, unsigned_den);
    signed_cov = signed_cg.get_inst_coverage(signed_num, signed_den);
    wildcard_cov = wildcard_cg.get_inst_coverage(wildcard_num, wildcard_den);
    $display("VALUE_RESOLUTION unsigned=%f %0d/%0d signed=%f %0d/%0d wildcard=%f %0d/%0d",
             unsigned_cov, unsigned_num, unsigned_den,
             signed_cov, signed_num, signed_den,
             wildcard_cov, wildcard_num, wildcard_den);
  end
endmodule
