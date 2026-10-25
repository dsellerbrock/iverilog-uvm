module netlist;
    interconnect iwire;
    dut1 child1(iwire);
    dut2 child2(iwire);
endmodule
module dut1(inout wire w);
    assign w = 1'b1;
    initial begin #1; $display("%b", w); end
endmodule
module dut2(inout wand w);
    assign w = 1'b0;
endmodule
