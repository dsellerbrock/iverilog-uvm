package pkg;
    int used = 17;
    int unused = 18;
endpackage

module top;
    import pkg::used;
    int copy;

    initial begin
        copy = used;
        #0;
        $probe();
        $finish;
    end
endmodule
