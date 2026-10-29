module issue1427_with_signed_item;
  covergroup filtered_cg with function sample(input logic signed [3:0] value);
    cp: coverpoint value { bins negative[] = {[-2:2]} with (item < 0); }
  endgroup
  covergroup direct_cg with function sample(input logic signed [3:0] value);
    cp: coverpoint value { bins negative[] = {[-2:-1]}; }
  endgroup

  filtered_cg filtered = new;
  direct_cg direct = new;

  initial begin
    filtered.sample(-1);
    direct.sample(-1);
    if (filtered.get_inst_coverage() != 50.0
        || direct.get_inst_coverage() != 50.0)
      $fatal(1, "issue1427 after -1: filtered=%0.1f direct=%0.1f",
             filtered.get_inst_coverage(), direct.get_inst_coverage());

    filtered.sample(-2);
    direct.sample(-2);
    if (filtered.get_inst_coverage() != 100.0
        || direct.get_inst_coverage() != 100.0)
      $fatal(1, "issue1427 after -2: filtered=%0.1f direct=%0.1f",
             filtered.get_inst_coverage(), direct.get_inst_coverage());

    $display("PASSED");
  end
endmodule
