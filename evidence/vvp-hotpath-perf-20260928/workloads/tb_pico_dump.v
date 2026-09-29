`timescale 1 ns / 1 ps
// CPU-style RTL workload: picorv32 testbench_ez with its per-access
// $display replaced by an access checksum, run for `CYC cycles.
module testbench;
	reg clk = 1;
	reg resetn = 0;
	wire trap;
	reg [31:0] hash = 0;
	integer accesses = 0;
	reg [31:0] memory [0:255];

	always #5 clk = ~clk;

	initial begin
		$dumpfile("pico_dump.fst");
		$dumpvars(0, testbench);
	end

	initial begin
		repeat (100) @(posedge clk);
		resetn <= 1;
		repeat (`CYC) @(posedge clk);
		$display("accesses=%0d hash=%h mem[255]=%h", accesses, hash, memory[255]);
		$finish;
	end

	wire mem_valid;
	wire mem_instr;
	reg mem_ready;
	wire [31:0] mem_addr;
	wire [31:0] mem_wdata;
	wire [3:0] mem_wstrb;
	reg  [31:0] mem_rdata;

	always @(posedge clk) begin
		if (mem_valid && mem_ready) begin
			accesses = accesses + 1;
			hash = {hash[30:0], hash[31]} ^ mem_addr ^ (mem_wstrb ? mem_wdata : mem_rdata);
		end
	end

	picorv32 #(
	) uut (
		.clk         (clk        ),
		.resetn      (resetn     ),
		.trap        (trap       ),
		.mem_valid   (mem_valid  ),
		.mem_instr   (mem_instr  ),
		.mem_ready   (mem_ready  ),
		.mem_addr    (mem_addr   ),
		.mem_wdata   (mem_wdata  ),
		.mem_wstrb   (mem_wstrb  ),
		.mem_rdata   (mem_rdata  )
	);

	initial begin
		memory[0] = 32'h 3fc00093; //       li      x1,1020
		memory[1] = 32'h 0000a023; //       sw      x0,0(x1)
		memory[2] = 32'h 0000a103; // loop: lw      x2,0(x1)
		memory[3] = 32'h 00110113; //       addi    x2,x2,1
		memory[4] = 32'h 0020a023; //       sw      x2,0(x1)
		memory[5] = 32'h ff5ff06f; //       j       <loop>
	end

	always @(posedge clk) begin
		mem_ready <= 0;
		if (mem_valid && !mem_ready) begin
			if (mem_addr < 1024) begin
				mem_ready <= 1;
				mem_rdata <= memory[mem_addr >> 2];
				if (mem_wstrb[0]) memory[mem_addr >> 2][ 7: 0] <= mem_wdata[ 7: 0];
				if (mem_wstrb[1]) memory[mem_addr >> 2][15: 8] <= mem_wdata[15: 8];
				if (mem_wstrb[2]) memory[mem_addr >> 2][23:16] <= mem_wdata[23:16];
				if (mem_wstrb[3]) memory[mem_addr >> 2][31:24] <= mem_wdata[31:24];
			end
		end
	end
endmodule
