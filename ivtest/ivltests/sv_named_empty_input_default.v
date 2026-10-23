module sv_named_empty_input_default_child (
    input wire [3:0] d = 4'h5,
    output wire [3:0] q
);
    assign q = d;
endmodule

module sv_named_empty_input_default;
    wire [3:0] omitted_q;
    wire [3:0] empty_q;
    wire [3:0] connected_q;

    sv_named_empty_input_default_child omitted(.q(omitted_q));
    sv_named_empty_input_default_child empty(.d(), .q(empty_q));
    sv_named_empty_input_default_child connected(.d(4'h0), .q(connected_q));

    initial begin
        #1;
        $display("omitted=%b empty=%b connected=%b",
                 omitted_q, empty_q, connected_q);
        if (omitted_q !== 4'h5 || empty_q !== 4'bzzzz || connected_q !== 4'h0)
            $fatal(1, "named empty input port connection mismatch");
        $display("PASSED");
    end
endmodule
