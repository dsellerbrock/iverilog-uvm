interface bus_if #(parameter W=8) (input bit clk);
  logic [W-1:0] data;
endinterface
module t;
  bit clk = 0;
  bus_if #(.W(16)) b16 (clk);
  initial begin
    virtual bus_if #(16) v16 = b16;
    // 1) direct (non-virtual) interface write at width 16
    b16.data = 16'hBEEF;
    #1 $display("NONVIRT b16.data=%0h (expect beef)", b16.data);
    // 2) virtual interface WRITE
    v16.data = 16'h1357;
    #1 $display("VIRT-W  b16.data=%0h (expect 1357)", b16.data);
    // 3) virtual interface READ
    b16.data = 16'h9ABC;
    #1 $display("VIRT-R  v16.data=%0h (expect 9abc)", v16.data);
    $finish;
  end
endmodule
