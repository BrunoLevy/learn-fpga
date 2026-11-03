module tb_quark_xprop;
    reg clk = 0, reset = 0;
    always #1 clk = ~clk;

    wire [31:0] mem_addr, mem_wdata;
    wire [3:0]  mem_wmask;
    wire        mem_rstrb;
    wire [31:0] mem_rdata;
    reg         mem_rbusy = 0, mem_wbusy = 0;

    reg [31:0] mem [0:16383];
    integer i;

    FemtoRV32 dut (
        .clk(clk),
        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wmask(mem_wmask),
        .mem_rdata(mem_rdata),
        .mem_rstrb(mem_rstrb),
        .mem_rbusy(mem_rbusy),
        .mem_wbusy(mem_wbusy),
        .reset(reset)
    );

    assign mem_rdata = mem[mem_addr[15:2]];

    always @(posedge clk)
        if (mem_wmask != 4'b0000)
            mem[mem_addr[15:2]] <= mem_wdata;

    initial begin
        for (i = 0; i < 16384; i = i + 1)
            mem[i] = 32'h00000013; // nop
        mem[0] = 32'h00500093;     // addi x1, x0, 5

        repeat (3) @(negedge clk);
        reset = 1;
        repeat (12) @(posedge clk);
        if (dut.registerFile[1] == 5) $display("PASS: x1=%0d", dut.registerFile[1]); else $display("FAIL: x1=%0d", dut.registerFile[1]);
        $finish;
    end

    always @(posedge clk)
        $display("t=%0t reset=%b state=%b mem_addr=%h aluShamt=%b rstrb=%b rbusy=%b",
                 $time, reset, dut.state, mem_addr, dut.aluShamt, mem_rstrb, mem_rbusy);
endmodule
