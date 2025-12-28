////////////////////////////////////////////////////////////////////////////////
// FemtoRV RISCOF testbench
// FemtoRV32 as DUT
////////////////////////////////////////////////////////////////////////////////
// Copyright 2025 Iztok Jeras
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
///////////////////////////////////////////////////////////////////////////////

module riscof_tb #(
    // memory parameters
    parameter int unsigned MEM_BASE = 32'h8000_0000,
    parameter int unsigned MEM_SIZE = 32'h0020_0000,
    // global constants
    localparam int unsigned XLEN = 32
)();

    // runtime arguments
    string       test_dir;
    int unsigned tohost;
    int unsigned fromhost;
    int unsigned begin_signature;
    int unsigned end_signature;

    // system signals
    logic clk = 1'b1;  // clock
    logic rst = 1'b1;  // reset

    // system bus
    logic [XLEN  -1:0]        mem_addr ;  // address bus
    logic [XLEN/8-1:0][8-1:0] mem_wdata;  // data to be written
    logic [XLEN/8-1:0]        mem_wmask;  // write mask for the 4 bytes of each word
    logic [XLEN/8-1:0][8-1:0] mem_rdata;  // input lines for both data and instr
    logic                     mem_rstrb;  // active to initiate memory read (used by IO)
    logic                     mem_rbusy;  // asserted if memory is busy reading value
    logic                     mem_wbusy;  // asserted if memory is busy writing value

    // memory array
    logic [8-1:0] memory_array [0:MEM_SIZE-1];

    // address
    logic [XLEN-1:0] addr;

    // interrupt request
    logic irq = 1'b0;

    ////////////////////////////////////////////////////////////////////////////////
    // RTL DUT instance
    ////////////////////////////////////////////////////////////////////////////////

    FemtoRV32 #(
        .RESET_ADDR (32'h8000_0000),
        .ADDR_WIDTH (XLEN)
    ) DUT (
        .clk       ( clk),
        .reset     (~rst),       // set to 0 to reset the processor
        .mem_addr  (mem_addr ),  // address bus
        .mem_wdata (mem_wdata),  // data to be written
        .mem_wmask (mem_wmask),  // write mask for the 4 bytes of each word
        .mem_rdata (mem_rdata),  // input lines for both data and instr
        .mem_rstrb (mem_rstrb),  // active to initiate memory read (used by IO)
        .mem_rbusy (mem_rbusy),  // asserted if memory is busy reading value
        .mem_wbusy (mem_wbusy)   // asserted if memory is busy writing value
`ifdef INTERRUPT
        ,
        .interrupt_request (irq)
`endif
    );

    ////////////////////////////////////////////////////////////////////////////////
    // memory
    ////////////////////////////////////////////////////////////////////////////////

    // handle LSB address
//  assign addr = {mem_addr[XLEN-1:2], mem_rstrb | |mem_wdata ? 2'b00 : mem_addr[1:0]};
    assign addr = {mem_addr[XLEN-1:2], 2'b00};

    // memory array
    always_ff @(posedge clk)
    begin
        // write access
        for (int unsigned i=0; i<XLEN/8; i++) begin
            if (mem_wmask[i]) memory_array[addr+i] <= mem_wdata[i];
        end
        // read access
        // TODO: always reading, no power saving
//        if (mem_rstrb) begin
        if (1'b1) begin
            for (int unsigned i=0; i<XLEN/8; i++) begin
                mem_rdata[i] <= memory_array[addr+i];
            end
        end
    end

    // memory control signals
    always_ff @(posedge rst, posedge clk)
    begin
        if (rst) begin
            mem_wbusy <= 1'b1;
            mem_rbusy <= 1'b1;
        end else begin
            // write access
            mem_wbusy <= 1'b0;
            // read access
            // TODO: always reading, no power saving
            //mem_rbusy <= ~mem_rstrb;
            mem_rbusy <= 1'b0;
        end
    end

    // memory initialization
    function int memory_init_bin (
        string filename,
        int unsigned mem_begin = 0
    );
        int code;  // status code
        int fd;    // file descriptor
        bit [640-1:0] err;
        fd = $fopen(filename, "rb");
        code = $fread(memory_array, fd);
`ifndef VERILATOR
        if (code == 0) begin
            code = $ferror(fd, err);
            $display("DEBUG: read_bin: code = %d, err = %s", code, err);
        end else begin
            $display("DEBUG: read %dB from binary file", code);
        end
`endif
        $fclose(fd);
        return code;
    endfunction: memory_init_bin

    // memory initialization
    function int unsigned memory_dump_hex (
        string filename,
        int unsigned mem_begin = 0,
        int unsigned mem_end = 0
    );
        int fd;    // file descriptor
        fd = $fopen(filename, "w");
        // check if file was opened successfully
        if (fd == 0) return 0;
        for (int unsigned addr=mem_begin; addr<mem_end; addr+=XLEN/8) begin
            for (int unsigned i=0; i<XLEN/8; i++) begin
                $fwrite(fd, "%02h", memory_array[addr+XLEN/8-1-i]);
            end
            $fwrite(fd, "\n");

        end
        $fclose(fd);
        return mem_end-mem_begin;
    endfunction: memory_dump_hex

    ////////////////////////////////////////////////////////////////////////////////
    // controller
    ////////////////////////////////////////////////////////////////////////////////

    // clock
    always #(20ns/2) clk = ~clk;

    /* verilator lint_off INITIALDLY */
    initial
    begin: main
        string firmware, signature;
        logic htif_halt = 1'b0;
        int unsigned cnt = 0;

        // get/display test directory from plusargs
        assert ($value$plusargs("TEST_DIR=%s"       , test_dir       ))  $display("RISCOF: test_dir = \'%s\'", test_dir);  else  $fatal(0, "RISCOF: test_dir $plusarg not found!");
        // get/display ELF symbols from plusargs
        assert ($value$plusargs("begin_signature=%h", begin_signature))  $display("HTIF: begin_signature = 0x%08h", begin_signature);  else  $fatal(0, "HTIF: begin_signature $plusarg not found!");
        assert ($value$plusargs("end_signature=%h"  , end_signature  ))  $display("HTIF: end_signature   = 0x%08h", end_signature  );  else  $fatal(0, "HTIF: end_signature   $plusarg not found!");
        assert ($value$plusargs("tohost=%h"         , tohost         ))  $display("HTIF: tohost          = 0x%08h", tohost         );  else  $fatal(0, "HTIF: tohost          $plusarg not found!");
        assert ($value$plusargs("fromhost=%h"       , fromhost       ))  $display("HTIF: fromhost        = 0x%08h", fromhost       );  else  $fatal(0, "HTIF: fromhost        $plusarg not found!");

        // waveforms
        // TODO
        $dumpfile({test_dir, "dut.fst"});
        $dumpvars(0);

        // load binary file into memory
        firmware = {test_dir, "dut.bin"};
        $display("Loading file into memory: %s", firmware);
        assert (memory_init_bin(firmware) > 0) begin
            $display("RISCOF: loaded firmware file \'%s\' into memory.", firmware);
        end else begin
            $fatal  ("RISCOF: firmware file \'%s\' not found.", firmware);
        end

        // RESET sequence
        repeat (4) @(posedge clk);
        rst <= 1'b0;

        // wait for HTIF halt request
        signature = {test_dir, "DUT-FemtoRV.signature"};
        do begin
            @(posedge clk);
            // increment counter and check for timeout
            cnt <= cnt+1;
            htif_halt <= (cnt > 40_000);
            // check write into HTIF tohost
            if (&mem_wmask && (mem_addr == tohost + 32'h0000_0000)) begin
                htif_halt <= mem_wdata[0][0];
            end
            if (htif_halt) begin
                assert (memory_dump_hex(signature, begin_signature-MEM_BASE, end_signature-MEM_BASE) > 0) begin
                    $display("RISCOF: saved signature from 0x%8h to 0x%8h into file \'%s\'", begin_signature, end_signature, signature);
                end else begin
                    $fatal  ("RISCOF: could not save signature file \'%s\'.", signature);
                end
            end
        end while (!htif_halt);
        // wait a few clock cycles before finishing simulation
        repeat(4) @(posedge clk);
        $finish;
    end: main
    /* verilator lint_on INITIALDLY */

    ////////////////////////////////////////////////////////////////////////////////
    // verbose execution trace
    ////////////////////////////////////////////////////////////////////////////////

endmodule: riscof_tb
