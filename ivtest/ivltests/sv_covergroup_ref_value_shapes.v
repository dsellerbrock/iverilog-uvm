module sv_covergroup_ref_value_shapes;
  logic [1:0] four_state;
  logic signed [3:0] signed_value;

  covergroup four_state_cg(ref logic [1:0] value);
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    cp: coverpoint value {
      bins x_zero = {2'bx0};
      bins z_one = {2'bz1};
      bins zero = {2'b00};
    }
  endgroup

  covergroup signed_cg(ref logic signed [3:0] value);
    option.per_instance = 1;
    option.get_inst_coverage = 1;
    cp: coverpoint value {
      bins negative = {[-8:-1]};
      bins positive = {[1:7]};
    }
  endgroup

  four_state_cg four_state_instance;
  signed_cg signed_instance;

  initial begin
    four_state = 2'bx0;
    signed_value = -1;
    four_state_instance = new(four_state);
    signed_instance = new(signed_value);

    four_state_instance.sample();
    if (four_state_instance.get_inst_coverage() < 33.0 ||
        four_state_instance.get_inst_coverage() > 34.0)
      $fatal(1, "ref covergroup did not preserve the X sample");
    four_state = 2'bz1;
    four_state_instance.sample();
    if (four_state_instance.get_inst_coverage() < 66.0 ||
        four_state_instance.get_inst_coverage() > 67.0)
      $fatal(1, "ref covergroup did not preserve the Z sample");
    four_state = 2'b00;
    four_state_instance.sample();
    if (four_state_instance.get_inst_coverage() != 100.0)
      $fatal(1, "ref covergroup did not match the known value after X/Z");

    signed_instance.sample();
    if (signed_instance.get_inst_coverage() != 50.0)
      $fatal(1, "ref covergroup did not preserve signed negative value");
    signed_value = 1;
    signed_instance.sample();
    if (signed_instance.get_inst_coverage() != 100.0)
      $fatal(1, "ref covergroup did not preserve signed positive value");

    $display("PASSED");
  end
endmodule
