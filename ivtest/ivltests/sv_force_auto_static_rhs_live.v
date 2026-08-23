module sv_force_auto_static_rhs_live;
  logic [15:0] concat_dst;
  logic signed [15:0] signed_dst;
  logic signed [7:0] local_dst;
  logic [7:0] high_byte;
  logic [7:0] low_byte;
  logic signed [7:0] signed_source;

  task automatic install_forces;
    force concat_dst = {high_byte, low_byte};
    force signed_dst = signed_source - 8'sd1;
  endtask

  task automatic install_static_local_force;
    static logic signed [7:0] local_source;
    local_source = -8'sd2;
    force local_dst = local_source - 8'sd1;
    #0;
    if (local_dst !== -8'sd3) begin
      $display("FAILED static-local initial value=%h", local_dst);
      $finish;
    end
    local_source = -8'sd5;
    #0;
    if (local_dst !== -8'sd6) begin
      $display("FAILED static-local live value=%h", local_dst);
      $finish;
    end
  endtask

  task automatic expect_values(input logic [15:0] expected_concat,
                               input logic signed [15:0] expected_signed,
                               input int step);
    if (concat_dst !== expected_concat || signed_dst !== expected_signed) begin
      $display("FAILED step=%0d concat=%h signed=%h expected_concat=%h expected_signed=%h",
               step, concat_dst, signed_dst, expected_concat, expected_signed);
      $finish;
    end
  endtask

  initial begin
    high_byte = 8'h12;
    low_byte = 8'h34;
    signed_source = -8'sd2;
    install_forces();
    install_static_local_force();
    #0 expect_values(16'h1234, -16'sd3, 1);
    if (local_dst !== -8'sd6) begin
      $display("FAILED static-local value after task return=%h", local_dst);
      $finish;
    end

    // The automatic task activation is gone, but its procedural forces and
    // their continuously evaluated static RHS expressions remain active.
    high_byte = 8'hab;
    low_byte = 8'hcd;
    signed_source = -8'sd5;
    #0 expect_values(16'habcd, -16'sd6, 2);

    concat_dst = 16'hffff;
    signed_dst = 16'sd7;
    local_dst = 8'sd7;
    #0 expect_values(16'habcd, -16'sd6, 3);
    if (local_dst !== -8'sd6) begin
      $display("FAILED static-local force after procedural write=%h", local_dst);
      $finish;
    end

    release concat_dst;
    release signed_dst;
    release local_dst;
    high_byte = 8'hde;
    low_byte = 8'had;
    signed_source = 8'sd10;
    #0 expect_values(16'habcd, -16'sd6, 4);

    concat_dst = 16'h5678;
    signed_dst = -16'sd9;
    local_dst = -8'sd10;
    #0 expect_values(16'h5678, -16'sd9, 5);
    if (local_dst !== -8'sd10) begin
      $display("FAILED static-local write after release=%h", local_dst);
      $finish;
    end

    $display("PASSED");
  end
endmodule
