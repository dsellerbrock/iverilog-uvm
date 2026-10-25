interface ifa;
endinterface

interface ifb;
endinterface

module mi(ifa p);
endmodule

module top;
    ifb b();
    mi u(b);
endmodule
