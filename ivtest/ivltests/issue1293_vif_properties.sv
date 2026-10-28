interface bus;
    logic x;
    modport mp(input x);
endinterface

module top;
    bus b();
    virtual interface bus vi = b;
    virtual interface bus.mp vmp = b;
endmodule
