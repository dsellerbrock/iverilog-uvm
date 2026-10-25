module netlist;
    interconnect iwire;
    dut1 child1(iwire);
    dut2 child2(iwire);
    initial begin #1; $display("K5 netlist %b", iwire); end
endmodule
module dut1(inout wire w);
    assign w = 1'b1;
    initial begin #1; $display("K5 dut1 %b", w); end
endmodule
module dut2(inout wand w);
    assign w = 1'b0;
endmodule
