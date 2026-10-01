class mubi_cov #(parameter int Width = 4);
endclass

class dv_base_mubi_cov;
  int created;
  int sampled;
  function void create_cov(int width);
    created = width;
  endfunction
  function void sample(int value);
    sampled += value;
  endfunction
endclass

class dv_base_reg_field;
  dv_base_mubi_cov mubi_cov;
  function void create_mubi_cov(int width);
    mubi_cov = new;
    mubi_cov.create_cov(width);
  endfunction
  function void sample_mubi(int value);
    if (mubi_cov != null) mubi_cov.sample(value);
  endfunction
endclass

module sv_implicit_property_method_collision;
  initial begin
    dv_base_reg_field field;
    field = new;
    field.create_mubi_cov(7);
    field.sample_mubi(3);
    if (field.mubi_cov == null || field.mubi_cov.created != 7
        || field.mubi_cov.sampled != 3)
      $fatal(1, "property receiver lookup failed");
    $display("PASSED");
  end
endmodule
