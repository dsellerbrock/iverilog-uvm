module sv_force_assign_legal_targets;
  logic [3:0] q, r;
  logic [7:0] mem [0:1];
  wire [7:0] bus;
  assign bus = 8'ha5;

  initial begin
    q = 4'h0;
    force q = 4'ha;
    #0;
    if (q !== 4'ha) begin
      $display("FAILED whole variable force");
      $finish;
    end
    release q;
    #0;
    if (q !== 4'ha) begin
      $display("FAILED whole variable release retention");
      $finish;
    end
    q = 4'h3;
    if (q !== 4'h3) begin
      $display("FAILED post-release variable write");
      $finish;
    end

    assign {q, r} = 8'h5a;
    #0;
    if ({q, r} !== 8'h5a) begin
      $display("FAILED whole concat assign");
      $finish;
    end
    deassign {q, r};
    #0;
    if ({q, r} !== 8'h5a) begin
      $display("FAILED whole concat deassign retention");
      $finish;
    end

    {q[1], q[0]} = 2'b10;
    if (q[1:0] !== 2'b10) begin
      $display("FAILED blocking concat of selects");
      $finish;
    end

    force bus[7:4] = 4'h3;
    #0;
    if (bus !== 8'h35) begin
      $display("FAILED net part-select force");
      $finish;
    end
    release bus[7:4];
    #0;
    if (bus !== 8'ha5) begin
      $display("FAILED net part-select release");
      $finish;
    end

    mem[1] = 8'h11;
    force mem[1] = 8'hcc;
    #0;
    if (mem[1] !== 8'hcc) begin
      $display("FAILED whole array word force");
      $finish;
    end
    release mem[1];
    #0;
    if (mem[1] !== 8'hcc) begin
      $display("FAILED whole array word release retention");
      $finish;
    end
    mem[1] = 8'h55;
    if (mem[1] !== 8'h55) begin
      $display("FAILED post-release array word write");
      $finish;
    end

    $display("PASSED");
  end
endmodule
