/**************************************************************************
*
*    File Name:  MT48LC16M16A2.V  
*      Version:  2.1
*         Date:  June 6th, 2002
*        Model:  BUS Functional
*    Simulator:  Model Technology
*
* Dependencies:  None
*
*        Email:  modelsupport@micron.com
*      Company:  Micron Technology, Inc.
*        Model:  MT48LC16M16A2 (4Meg x 16 x 4 Banks)
*
*  Description:  Micron 256Mb SDRAM Verilog model
*
*   Limitation:  - Doesn't check for 8192 cycle refresh
*
*         Note:  - Set simulator resolution to "ps" accuracy
*                - Set Debug = 0 to disable $display messages
*
*   Disclaimer:  THESE DESIGNS ARE PROVIDED "AS IS" WITH NO WARRANTY 
*                WHATSOEVER AND MICRON SPECIFICALLY DISCLAIMS ANY 
*                IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR
*                A PARTICULAR PURPOSE, OR AGAINST INFRINGEMENT.
*
*                Copyright © 2001 Micron Semiconductor Products, Inc.
*                All rights researved
*
* Rev  Author          Date        Changes
* ---  --------------------------  ---------------------------------------
* 2.1  SH              06/06/2002  - Typo in bank multiplex
*      Micron Technology Inc.
*
* 2.0  SH              04/30/2002  - Second release
*      Micron Technology Inc.
*
**************************************************************************/

`timescale 1ns / 1ps

module mt48lc16m16a2 (Dq, Addr, Ba, Clk, Cke, Cs_n, Ras_n, Cas_n, We_n, Dqm);

    parameter addr_bits =      13;
    parameter data_bits =      16;
    parameter col_bits  =       9;
    parameter mem_sizes = 4194303;

    inout     [data_bits - 1 : 0] Dq;
    input     [addr_bits - 1 : 0] Addr;
    input                 [1 : 0] Ba;
    input                         Clk;
    input                         Cke;
    input                         Cs_n;
    input                         Ras_n;
    input                         Cas_n;
    input                         We_n;
    input                 [1 : 0] Dqm;

    reg       [data_bits - 1 : 0] Bank0 [0 : mem_sizes];
    reg       [data_bits - 1 : 0] Bank1 [0 : mem_sizes];
    reg       [data_bits - 1 : 0] Bank2 [0 : mem_sizes];
    reg       [data_bits - 1 : 0] Bank3 [0 : mem_sizes];

    reg                   [1 : 0] Bank_addr [0 : 3];                // Bank Address Pipeline
    reg        [col_bits - 1 : 0] Col_addr [0 : 3];                 // Column Address Pipeline
    reg                   [3 : 0] Command [0 : 3];                  // Command Operation Pipeline
    reg                   [1 : 0] Dqm_reg0, Dqm_reg1;               // DQM Operation Pipeline
    reg       [addr_bits - 1 : 0] B0_row_addr, B1_row_addr, B2_row_addr, B3_row_addr;

    reg       [addr_bits - 1 : 0] Mode_reg;
    reg       [data_bits - 1 : 0] Dq_reg, Dq_dqm;
    reg        [col_bits - 1 : 0] Col_temp, Burst_counter;

    reg                           Act_b0, Act_b1, Act_b2, Act_b3;   // Bank Activate
    reg                           Pc_b0, Pc_b1, Pc_b2, Pc_b3;       // Bank Precharge

    reg                   [1 : 0] Bank_precharge       [0 : 3];     // Precharge Command
    reg                           A10_precharge        [0 : 3];     // Addr[10] = 1 (All banks)
    reg                           Auto_precharge       [0 : 3];     // RW Auto Precharge (Bank)
    reg                           Read_precharge       [0 : 3];     // R  Auto Precharge
    reg                           Write_precharge      [0 : 3];     //  W Auto Precharge
    reg                           RW_interrupt_read    [0 : 3];     // RW Interrupt Read with Auto Precharge
    reg                           RW_interrupt_write   [0 : 3];     // RW Interrupt Write with Auto Precharge
    reg                   [1 : 0] RW_interrupt_bank;                // RW Interrupt Bank
    integer                       RW_interrupt_counter [0 : 3];     // RW Interrupt Counter
    integer                       Count_precharge      [0 : 3];     // RW Auto Precharge Counter

    reg                           Data_in_enable;
    reg                           Data_out_enable;

    reg                   [1 : 0] Bank, Prev_bank;
    reg       [addr_bits - 1 : 0] Row;
    reg        [col_bits - 1 : 0] Col, Col_brst;

    // Internal system clock
    reg                           CkeZ, Sys_clk;

    // Commands Decode
    wire      Active_enable    = ~Cs_n & ~Ras_n &  Cas_n &  We_n;
    wire      Aref_enable      = ~Cs_n & ~Ras_n & ~Cas_n &  We_n;
    wire      Burst_term       = ~Cs_n &  Ras_n &  Cas_n & ~We_n;
    wire      Mode_reg_enable  = ~Cs_n & ~Ras_n & ~Cas_n & ~We_n;
    wire      Prech_enable     = ~Cs_n & ~Ras_n &  Cas_n & ~We_n;
    wire      Read_enable      = ~Cs_n &  Ras_n & ~Cas_n &  We_n;
    wire      Write_enable     = ~Cs_n &  Ras_n & ~Cas_n & ~We_n;

    // Burst Length Decode
    wire      Burst_length_1   = ~Mode_reg[2] & ~Mode_reg[1] & ~Mode_reg[0];
    wire      Burst_length_2   = ~Mode_reg[2] & ~Mode_reg[1] &  Mode_reg[0];
    wire      Burst_length_4   = ~Mode_reg[2] &  Mode_reg[1] & ~Mode_reg[0];
    wire      Burst_length_8   = ~Mode_reg[2] &  Mode_reg[1] &  Mode_reg[0];
    wire      Burst_length_f   =  Mode_reg[2] &  Mode_reg[1] &  Mode_reg[0];

    // CAS Latency Decode
    wire      Cas_latency_2    = ~Mode_reg[6] &  Mode_reg[5] & ~Mode_reg[4];
    wire      Cas_latency_3    = ~Mode_reg[6] &  Mode_reg[5] &  Mode_reg[4];

    // Write Burst Mode
    wire      Write_burst_mode = Mode_reg[9];

    wire      Debug            = 1'b1;                          // Debug messages : 1 = On
    wire      Dq_chk           = Sys_clk & Data_in_enable;      // Check setup/hold time for DQ
    
    assign    Dq               = Dq_reg;                        // DQ buffer

    // Commands Operation
    `define   ACT       0
    `define   NOP       1
    `define   READ      2
    `define   WRITE     3
    `define   PRECH     4
    `define   A_REF     5
    `define   BST       6
    `define   LMR       7

    // Timing Parameters for -7E PC133 CL2
    parameter tAC  =   5.4;
    parameter tHZ  =   5.4;
    parameter tOH  =   3.0;
    parameter tMRD =   2.0;     // 2 Clk Cycles
    parameter tRAS =  37.0;
    parameter tRC  =  60.0;
    parameter tRCD =  15.0;
    parameter tRFC =  66.0;
    parameter tRP  =  15.0;
    parameter tRRD =  14.0;
    parameter tWRa =   7.0;     // A2 Version - Auto precharge mode (1 Clk + 7 ns)
    parameter tWRm =  14.0;     // A2 Version - Manual precharge mode (14 ns)

    // Timing Check variable
    time  MRD_chk;
    time  WR_chkm [0 : 3];
    time  RFC_chk, RRD_chk;
    time  RC_chk0, RC_chk1, RC_chk2, RC_chk3;
    time  RAS_chk0, RAS_chk1, RAS_chk2, RAS_chk3;
    time  RCD_chk0, RCD_chk1, RCD_chk2, RCD_chk3;
    time  RP_chk0, RP_chk1, RP_chk2, RP_chk3;

    initial begin
        Dq_reg = {data_bits{1'bz}};
        Data_in_enable = 0; Data_out_enable = 0;
        Act_b0 = 1; Act_b1 = 1; Act_b2 = 1; Act_b3 = 1;
        Pc_b0 = 0; Pc_b1 = 0; Pc_b2 = 0; Pc_b3 = 0;
        WR_chkm[0] = 0; WR_chkm[1] = 0; WR_chkm[2] = 0; WR_chkm[3] = 0;
        RW_interrupt_read[0] = 0; RW_interrupt_read[1] = 0; RW_interrupt_read[2] = 0; RW_interrupt_read[3] = 0;
        RW_interrupt_write[0] = 0; RW_interrupt_write[1] = 0; RW_interrupt_write[2] = 0; RW_interrupt_write[3] = 0;
        MRD_chk = 0; RFC_chk = 0; RRD_chk = 0;
        RAS_chk0 = 0; RAS_chk1 = 0; RAS_chk2 = 0; RAS_chk3 = 0;
        RCD_chk0 = 0; RCD_chk1 = 0; RCD_chk2 = 0; RCD_chk3 = 0;
        RC_chk0 = 0; RC_chk1 = 0; RC_chk2 = 0; RC_chk3 = 0;
        RP_chk0 = 0; RP_chk1 = 0; RP_chk2 = 0; RP_chk3 = 0;
        $timeformat (-9, 1, " ns", 12);
    end

    // System clock generator
    always begin
        @ (posedge Clk) begin
            Sys_clk = CkeZ;
            CkeZ = Cke;
        end
        @ (negedge Clk) begin
            Sys_clk = 1'b0;
        end
    end

    always @ (posedge Sys_clk) begin
        // Internal Commamd Pipelined
        Command[0] = Command[1];
        Command[1] = Command[2];
        Command[2] = Command[3];
        Command[3] = `NOP;

        Col_addr[0] = Col_addr[1];
        Col_addr[1] = Col_addr[2];
        Col_addr[2] = Col_addr[3];
        Col_addr[3] = {col_bits{1'b0}};

        Bank_addr[0] = Bank_addr[1];
        Bank_addr[1] = Bank_addr[2];
        Bank_addr[2] = Bank_addr[3];
        Bank_addr[3] = 2'b0;

        Bank_precharge[0] = Bank_precharge[1];
        Bank_precharge[1] = Bank_precharge[2];
        Bank_precharge[2] = Bank_precharge[3];
        Bank_precharge[3] = 2'b0;

        A10_precharge[0] = A10_precharge[1];
        A10_precharge[1] = A10_precharge[2];
        A10_precharge[2] = A10_precharge[3];
        A10_precharge[3] = 1'b0;

        // Dqm pipeline for Read
        Dqm_reg0 = Dqm_reg1;
        Dqm_reg1 = Dqm;

        // Read or Write with Auto Precharge Counter
        if (Auto_precharge[0] === 1'b1) begin
            Count_precharge[0] = Count_precharge[0] + 1;
        end
        if (Auto_precharge[1] === 1'b1) begin
            Count_precharge[1] = Count_precharge[1] + 1;
        end
        if (Auto_precharge[2] === 1'b1) begin
            Count_precharge[2] = Count_precharge[2] + 1;
        end
        if (Auto_precharge[3] === 1'b1) begin
            Count_precharge[3] = Count_precharge[3] + 1;
        end

        // Read or Write Interrupt Counter
        if (RW_interrupt_write[0] === 1'b1) begin
            RW_interrupt_counter[0] = RW_interrupt_counter[0] + 1;
        end
        if (RW_interrupt_write[1] === 1'b1) begin
            RW_interrupt_counter[1] = RW_interrupt_counter[1] + 1;
        end
        if (RW_interrupt_write[2] === 1'b1) begin
            RW_interrupt_counter[2] = RW_interrupt_counter[2] + 1;
        end
        if (RW_interrupt_write[3] === 1'b1) begin
            RW_interrupt_counter[3] = RW_interrupt_counter[3] + 1;
        end

        // tMRD Counter
        MRD_chk = MRD_chk + 1;

        // Auto Refresh
        if (Aref_enable === 1'b1) begin
            if (Debug) begin
                $display ("%m : at time %t AREF : Auto Refresh", $time);
            end

            // Auto Refresh to Auto Refresh
            if ($time - RFC_chk < tRFC) begin
                $display ("%m : at time %t ERROR: tRFC violation during Auto Refresh", $time);
            end

            // Precharge to Auto Refresh
            if (($time - RP_chk0 < tRP) || ($time - RP_chk1 < tRP) ||
                ($time - RP_chk2 < tRP) || ($time - RP_chk3 < tRP)) begin
                $display ("%m : at time %t ERROR: tRP violation during Auto Refresh", $time);
            end

            // Precharge to Refresh
            if (Pc_b0 === 1'b0 || Pc_b1 === 1'b0 || Pc_b2 === 1'b0 || Pc_b3 === 1'b0) begin
                $display ("%m : at time %t ERROR: All banks must be Precharge before Auto Refresh", $time);
            end

            // Load Mode Register to Auto Refresh
            if (MRD_chk < tMRD) begin
                $display ("%m : at time %t ERROR: tMRD violation during Auto Refresh", $time);
            end

            // Record Current tRFC time
            RFC_chk = $time;
        end
        
        // Load Mode Register
        if (Mode_reg_enable === 1'b1) begin
            // Register Mode
            Mode_reg = Addr;

            // Decode CAS Latency, Burst Length, Burst Type, and Write Burst Mode
            if (Debug) begin
                $display ("%m : at time %t LMR  : Load Mode Register", $time);
                // CAS Latency
                case (Addr[6 : 4])
                    3'b010  : $display ("%m :                             CAS Latency      = 2");
                    3'b011  : $display ("%m :                             CAS Latency      = 3");
                    default : $display ("%m :                             CAS Latency      = Reserved");
                endcase

                // Burst Length
                case (Addr[2 : 0])
                    3'b000  : $display ("%m :                             Burst Length     = 1");
                    3'b001  : $display ("%m :                             Burst Length     = 2");
                    3'b010  : $display ("%m :                             Burst Length     = 4");
                    3'b011  : $display ("%m :                             Burst Length     = 8");
                    3'b111  : $display ("%m :                             Burst Length     = Full");
                    default : $display ("%m :                             Burst Length     = Reserved");
                endcase

                // Burst Type
                if (Addr[3] === 1'b0) begin
                    $display ("%m :                             Burst Type       = Sequential");
                end else if (Addr[3] === 1'b1) begin
                    $display ("%m :                             Burst Type       = Interleaved");
                end else begin
                    $display ("%m :                             Burst Type       = Reserved");
                end

                // Write Burst Mode
                if (Addr[9] === 1'b0) begin
                    $display ("%m :                             Write Burst Mode = Programmed Burst Length");
                end else if (Addr[9] === 1'b1) begin
                    $display ("%m :                             Write Burst Mode = Single Location Access");
                end else begin
                    $display ("%m :                             Write Burst Mode = Reserved");
                end
            end

            // Precharge to Load Mode Register
            if (Pc_b0 === 1'b0 && Pc_b1 === 1'b0 && Pc_b2 === 1'b0 && Pc_b3 === 1'b0) begin
                $display ("%m : at time %t ERROR: all banks must be Precharge before Load Mode Register", $time);
            end

            // Precharge to Load Mode Register
            if (($time - RP_chk0 < tRP) || ($time - RP_chk1 < tRP) ||
                ($time - RP_chk2 < tRP) || ($time - RP_chk3 < tRP)) begin
                $display ("%m : at time %t ERROR: tRP violation during Load Mode Register", $time);
            end

            // Auto Refresh to Load Mode Register
            if ($time - RFC_chk < tRFC) begin
                $display ("%m : at time %t ERROR: tRFC violation during Load Mode Register", $time);
            end

            // Load Mode Register to Load Mode Register
            if (MRD_chk < tMRD) begin
                $display ("%m : at time %t ERROR: tMRD violation during Load Mode Register", $time);
            end

            // Reset MRD Counter
            MRD_chk = 0;
        end
        
        // Active Block (Latch Bank Address and Row Address)
        if (Active_enable === 1'b1) begin
            // Activate an open bank can corrupt data
            if ((Ba === 2'b00 && Act_b0 === 1'b1) || (Ba === 2'b01 && Act_b1 === 1'b1) ||
                (Ba === 2'b10 && Act_b2 === 1'b1) || (Ba === 2'b11 && Act_b3 === 1'b1)) begin
                $display ("%m : at time %t ERROR: Bank already activated -- data can be corrupted", $time);
            end

            // Activate Bank 0
            if (Ba === 2'b00 && Pc_b0 === 1'b1) begin
                // Debug Message
                if (Debug) begin
                    $display ("%m : at time %t ACT  : Bank = 0 Row = %d", $time, Addr);
                end

                // ACTIVE to ACTIVE command period
                if ($time - RC_chk0 < tRC) begin
                    $display ("%m : at time %t ERROR: tRC violation during Activate bank 0", $time);
                end

                // Precharge to Activate Bank 0
                if ($time - RP_chk0 < tRP) begin
                    $display ("%m : at time %t ERROR: tRP violation during Activate bank 0", $time);
                end

                // Record variables
                Act_b0 = 1'b1;
                Pc_b0 = 1'b0;
                B0_row_addr = Addr [addr_bits - 1 : 0];
                RAS_chk0 = $time;
                RC_chk0 = $time;
                RCD_chk0 = $time;
            end

            if (Ba == 2'b01 && Pc_b1 == 1'b1) begin
                // Debug Message
                if (Debug) begin
                    $display ("%m : at time %t ACT  : Bank = 1 Row = %d", $time, Addr);
                end

                // ACTIVE to ACTIVE command period
                if ($time - RC_chk1 < tRC) begin
                    $display ("%m : at time %t ERROR: tRC violation during Activate bank 1", $time);
                end

                // Precharge to Activate Bank 1
                if ($time - RP_chk1 < tRP) begin
                    $display ("%m : at time %t ERROR: tRP violation during Activate bank 1", $time);
                end

                // Record variables
                Act_b1 = 1'b1;
                Pc_b1 = 1'b0;
                B1_row_addr = Addr [addr_bits - 1 : 0];
                RAS_chk1 = $time;
                RC_chk1 = $time;
                RCD_chk1 = $time;
            end

            if (Ba == 2'b10 && Pc_b2 == 1'b1) begin
                // Debug Message
                if (Debug) begin
                    $display ("%m : at time %t ACT  : Bank = 2 Row = %d", $time, Addr);
                end

                // ACTIVE to ACTIVE command period
                if ($time - RC_chk2 < tRC) begin
                    $display ("%m : at time %t ERROR: tRC violation during Activate bank 2", $time);
                end

                // Precharge to Activate Bank 2
                if ($time - RP_chk2 < tRP) begin
                    $display ("%m : at time %t ERROR: tRP violation during Activate bank 2", $time);
                end

                // Record variables
                Act_b2 = 1'b1;
                Pc_b2 = 1'b0;
                B2_row_addr = Addr [addr_bits - 1 : 0];
                RAS_chk2 = $time;
                RC_chk2 = $time;
                RCD_chk2 = $time;
            end

            if (Ba == 2'b11 && Pc_b3 == 1'b1) begin
                // Debug Message
                if (Debug) begin
                    $display ("%m : at time %t ACT  : Bank = 3 Row = %d", $time, Addr);
                end

                // ACTIVE to ACTIVE command period
                if ($time - RC_chk3 < tRC) begin
                    $display ("%m : at time %t ERROR: tRC violation during Activate bank 3", $time);
                end

                // Precharge to Activate Bank 3
                if ($time - RP_chk3 < tRP) begin
                    $display ("%m : at time %t ERROR: tRP violation during Activate bank 3", $time);
                end

                // Record variables
                Act_b3 = 1'b1;
                Pc_b3 = 1'b0;
                B3_row_addr = Addr [addr_bits - 1 : 0];
                RAS_chk3 = $time;
                RC_chk3 = $time;
                RCD_chk3 = $time;
            end

            // Active Bank A to Active Bank B
            if ((Prev_bank != Ba) && ($time - RRD_chk < tRRD)) begin
                $display ("%m : at time %t ERROR: tRRD violation during Activate bank = %d", $time, Ba);
            end

            // Auto Refresh to Activate
            if ($time - RFC_chk < tRFC) begin
                $display ("%m : at time %t ERROR: tRFC violation during Activate bank = %d", $time, Ba);
            end

            // Load Mode Register to Active
            if (MRD_chk < tMRD ) begin
                $display ("%m : at time %t ERROR: tMRD violation during Activate bank = %d", $time, Ba);
            end

            // Record variables for checking violation
            RRD_chk = $time;
            Prev_bank = Ba;
        end
        
        // Precharge Block
        if (Prech_enable == 1'b1) begin
            // Load Mode Register to Precharge
            if ($time - MRD_chk < tMRD) begin
                $display ("%m : at time %t ERROR: tMRD violaiton during Precharge", $time);
            end

            // Precharge Bank 0
            if ((Addr[10] === 1'b1 || (Addr[10] === 1'b0 && Ba === 2'b00)) && Act_b0 === 1'b1) begin
                Act_b0 = 1'b0;
                Pc_b0 = 1'b1;
                RP_chk0 = $time;

                // Activate to Precharge
                if ($time - RAS_chk0 < tRAS) begin
                    $display ("%m : at time %t ERROR: tRAS violation during Precharge", $time);
                end

                // tWR violation check for write
                if ($time - WR_chkm[0] < tWRm) begin
                    $display ("%m : at time %t ERROR: tWR violation during Precharge", $time);
                end
            end

            // Precharge Bank 1
            if ((Addr[10] === 1'b1 || (Addr[10] === 1'b0 && Ba === 2'b01)) && Act_b1 === 1'b1) begin
                Act_b1 = 1'b0;
                Pc_b1 = 1'b1;
                RP_chk1 = $time;

                // Activate to Precharge
                if ($time - RAS_chk1 < tRAS) begin
                    $display ("%m : at time %t ERROR: tRAS violation during Precharge", $time);
                end

                // tWR violation check for write
                if ($time - WR_chkm[1] < tWRm) begin
                    $display ("%m : at time %t ERROR: tWR violation during Precharge", $time);
                end
            end

            // Precharge Bank 2
            if ((Addr[10] === 1'b1 || (Addr[10] === 1'b0 && Ba === 2'b10)) && Act_b2 === 1'b1) begin
                Act_b2 = 1'b0;
                Pc_b2 = 1'b1;
                RP_chk2 = $time;

                // Activate to Precharge
                if ($time - RAS_chk2 < tRAS) begin
                    $display ("%m : at time %t ERROR: tRAS violation during Precharge", $time);
                end

                // tWR violation check for write
                if ($time - WR_chkm[2] < tWRm) begin
                    $display ("%m : at time %t ERROR: tWR violation during Precharge", $time);
                end
            end

            // Precharge Bank 3
            if ((Addr[10] === 1'b1 || (Addr[10] === 1'b0 && Ba === 2'b11)) && Act_b3 === 1'b1) begin
                Act_b3 = 1'b0;
                Pc_b3 = 1'b1;
                RP_chk3 = $time;

                // Activate to Precharge
                if ($time - RAS_chk3 < tRAS) begin
                    $display ("%m : at time %t ERROR: tRAS violation during Precharge", $time);
                end

                // tWR violation check for write
                if ($time - WR_chkm[3] < tWRm) begin
                    $display ("%m : at time %t ERROR: tWR violation during Precharge", $time);
                end
            end

            // Terminate a Write Immediately (if same bank or all banks)
            if (Data_in_enable === 1'b1 && (Bank === Ba || Addr[10] === 1'b1)) begin
                Data_in_enable = 1'b0;
            end

            // Precharge Command Pipeline for Read
            if (Cas_latency_3 === 1'b1) begin
                Command[2] = `PRECH;
                Bank_precharge[2] = Ba;
                A10_precharge[2] = Addr[10];
            end else if (Cas_latency_2 === 1'b1) begin
                Command[1] = `PRECH;
                Bank_precharge[1] = Ba;
                A10_precharge[1] = Addr[10];
            end
        end
        
        // Burst terminate
        if (Burst_term === 1'b1) begin
            // Terminate a Write Immediately
            if (Data_in_enable == 1'b1) begin
                Data_in_enable = 1'b0;
            end

            // Terminate a Read Depend on CAS Latency
            if (Cas_latency_3 === 1'b1) begin
                Command[2] = `BST;
            end else if (Cas_latency_2 == 1'b1) begin
                Command[1] = `BST;
            end

            // Display debug message
            if (Debug) begin
                $display ("%m : at time %t BST  : Burst Terminate",$time);
            end
        end
        
        // Read, Write, Column Latch
        if (Read_enable === 1'b1) begin
            // Check to see if bank is open (ACT)
            if ((Ba == 2'b00 && Pc_b0 == 1'b1) || (Ba == 2'b01 && Pc_b1 == 1'b1) ||
                (Ba == 2'b10 && Pc_b2 == 1'b1) || (Ba == 2'b11 && Pc_b3 == 1'b1)) begin
                $display("%m : at time %t ERROR: Bank is not Activated for Read", $time);
            end

            // Activate to Read or Write
            if ((Ba == 2'b00) && ($time - RCD_chk0 < tRCD) ||
                (Ba == 2'b01) && ($time - RCD_chk1 < tRCD) ||
                (Ba == 2'b10) && ($time - RCD_chk2 < tRCD) ||
                (Ba == 2'b11) && ($time - RCD_chk3 < tRCD)) begin
                $display("%m : at time %t ERROR: tRCD violation during Read", $time);
            end

            // CAS Latency pipeline
            if (Cas_latency_3 == 1'b1) begin
                Command[2] = `READ;
                Col_addr[2] = Addr;
                Bank_addr[2] = Ba;
            end else if (Cas_latency_2 == 1'b1) begin
                Command[1] = `READ;
                Col_addr[1] = Addr;
                Bank_addr[1] = Ba;
            end

            // Read interrupt Write (terminate Write immediately)
            if (Data_in_enable == 1'b1) begin
                Data_in_enable = 1'b0;

                // Interrupting a Write with Autoprecharge
                if (Auto_precharge[RW_interrupt_bank] == 1'b1 && Write_precharge[RW_interrupt_bank] == 1'b1) begin
                    RW_interrupt_write[RW_interrupt_bank] = 1'b1;
                    RW_interrupt_counter[RW_interrupt_bank] = 0;

                    // Display debug message
                    if (Debug) begin
                        $display ("%m : at time %t NOTE : Read interrupt Write with Autoprecharge", $time);
                    end
                end
            end

            // Write with Auto Precharge
            if (Addr[10] == 1'b1) begin
                Auto_precharge[Ba] = 1'b1;
                Count_precharge[Ba] = 0;
                RW_interrupt_bank = Ba;
                Read_precharge[Ba] = 1'b1;
            end
        end

        // Write Command
        if (Write_enable == 1'b1) begin
            // Activate to Write
            if ((Ba == 2'b00 && Pc_b0 == 1'b1) || (Ba == 2'b01 && Pc_b1 == 1'b1) ||
                (Ba == 2'b10 && Pc_b2 == 1'b1) || (Ba == 2'b11 && Pc_b3 == 1'b1)) begin
                $display("%m : at time %t ERROR: Bank is not Activated for Write", $time);
            end

            // Activate to Read or Write
            if ((Ba == 2'b00) && ($time - RCD_chk0 < tRCD) ||
                (Ba == 2'b01) && ($time - RCD_chk1 < tRCD) ||
                (Ba == 2'b10) && ($time - RCD_chk2 < tRCD) ||
                (Ba == 2'b11) && ($time - RCD_chk3 < tRCD)) begin
                $display("%m : at time %t ERROR: tRCD violation during Read", $time);
            end

            // Latch Write command, Bank, and Column
            Command[0] = `WRITE;
            Col_addr[0] = Addr;
            Bank_addr[0] = Ba;

            // Write interrupt Write (terminate Write immediately)
            if (Data_in_enable == 1'b1) begin
                Data_in_enable = 1'b0;

                // Interrupting a Write with Autoprecharge
                if (Auto_precharge[RW_interrupt_bank] == 1'b1 && Write_precharge[RW_interrupt_bank] == 1'b1) begin
                    RW_interrupt_write[RW_interrupt_bank] = 1'b1;

                    // Display debug message
                    if (Debug) begin
                        $display ("%m : at time %t NOTE : Read Bank %d interrupt Write Bank %d with Autoprecharge", $time, Ba, RW_interrupt_bank);
                    end
                end
            end

            // Write interrupt Read (terminate Read immediately)
            if (Data_out_enable == 1'b1) begin
                Data_out_enable = 1'b0;
                
                // Interrupting a Read with Autoprecharge
                if (Auto_precharge[RW_interrupt_bank] == 1'b1 && Read_precharge[RW_interrupt_bank] == 1'b1) begin
                    RW_interrupt_read[RW_interrupt_bank] = 1'b1;

                    // Display debug message
                    if (Debug) begin
                        $display ("%m : at time %t NOTE : Write Bank %d interrupt Read Bank %d with Autoprecharge", $time, Ba, RW_interrupt_bank);
                    end
                end
            end

            // Write with Auto Precharge
            if (Addr[10] == 1'b1) begin
                Auto_precharge[Ba] = 1'b1;
                Count_precharge[Ba] = 0;
                RW_interrupt_bank = Ba;
                Write_precharge[Ba] = 1'b1;
            end
        end

        /*
            Write with Auto Precharge Calculation
                The device start internal precharge when:
                    1.  Meet minimum tRAS requirement
                and 2.  tWR cycle(s) after last valid data
                 or 3.  Interrupt by a Read or Write (with or without Auto Precharge)

            Note: Model is starting the internal precharge 1 cycle after they meet all the
                  requirement but tRP will be compensate for the time after the 1 cycle.
        */
        if ((Auto_precharge[0] == 1'b1) && (Write_precharge[0] == 1'b1)) begin
            if ((($time - RAS_chk0 >= tRAS) &&                                                          // Case 1
               (((Burst_length_1 == 1'b1 || Write_burst_mode == 1'b1) && Count_precharge [0] >= 1) ||   // Case 2
                 (Burst_length_2 == 1'b1                              && Count_precharge [0] >= 2) ||
                 (Burst_length_4 == 1'b1                              && Count_precharge [0] >= 4) ||
                 (Burst_length_8 == 1'b1                              && Count_precharge [0] >= 8))) ||
                 (RW_interrupt_write[0] == 1'b1 && RW_interrupt_counter[0] >= 1)) begin                 // Case 3
                    Auto_precharge[0] = 1'b0;
                    Write_precharge[0] = 1'b0;
                    RW_interrupt_write[0] = 1'b0;
                    Pc_b0 = 1'b1;
                    Act_b0 = 1'b0;
                    RP_chk0 = $time + tWRa;
                    if (Debug) begin
                        $display ("%m : at time %t NOTE : Start Internal Auto Precharge for Bank 0", $time);
                    end
            end
        end
        if ((Auto_precharge[1] == 1'b1) && (Write_precharge[1] == 1'b1)) begin
            if ((($time - RAS_chk1 >= tRAS) &&                                                          // Case 1
               (((Burst_length_1 == 1'b1 || Write_burst_mode == 1'b1) && Count_precharge [1] >= 1) ||   // Case 2
                 (Burst_length_2 == 1'b1                              && Count_precharge [1] >= 2) ||
                 (Burst_length_4 == 1'b1                              && Count_precharge [1] >= 4) ||
                 (Burst_length_8 == 1'b1                              && Count_precharge [1] >= 8))) ||
                 (RW_interrupt_write[1] == 1'b1 && RW_interrupt_counter[1] >= 1)) begin                 // Case 3
                    Auto_precharge[1] = 1'b0;
                    Write_precharge[1] = 1'b0;
                    RW_interrupt_write[1] = 1'b0;
                    Pc_b1 = 1'b1;
                    Act_b1 = 1'b0;
                    RP_chk1 = $time + tWRa;
                    if (Debug) begin
                        $display ("%m : at time %t NOTE : Start Internal Auto Precharge for Bank 1", $time);
                    end
            end
        end
        if ((Auto_precharge[2] == 1'b1) && (Write_precharge[2] == 1'b1)) begin
            if ((($time - RAS_chk2 >= tRAS) &&                                                          // Case 1
               (((Burst_length_1 == 1'b1 || Write_burst_mode == 1'b1) && Count_precharge [2] >= 1) ||   // Case 2
                 (Burst_length_2 == 1'b1                              && Count_precharge [2] >= 2) ||
                 (Burst_length_4 == 1'b1                              && Count_precharge [2] >= 4) ||
                 (Burst_length_8 == 1'b1                              && Count_precharge [2] >= 8))) ||
                 (RW_interrupt_write[2] == 1'b1 && RW_interrupt_counter[2] >= 1)) begin                 // Case 3
                    Auto_precharge[2] = 1'b0;
                    Write_precharge[2] = 1'b0;
                    RW_interrupt_write[2] = 1'b0;
                    Pc_b2 = 1'b1;
                    Act_b2 = 1'b0;
                    RP_chk2 = $time + tWRa;
                    if (Debug) begin
                        $display ("%m : at time %t NOTE : Start Internal Auto Precharge for Bank 2", $time);
                    end
            end
        end
        if ((Auto_precharge[3] == 1'b1) && (Write_precharge[3] == 1'b1)) begin
            if ((($time - RAS_chk3 >= tRAS) &&                                                          // Case 1
               (((Burst_length_1 == 1'b1 || Write_burst_mode == 1'b1) && Count_precharge [3] >= 1) ||   // Case 2
                 (Burst_length_2 == 1'b1                              && Count_precharge [3] >= 2) ||
                 (Burst_length_4 == 1'b1                              && Count_precharge [3] >= 4) ||
                 (Burst_length_8 == 1'b1                              && Count_precharge [3] >= 8))) ||
                 (RW_interrupt_write[3] == 1'b1 && RW_interrupt_counter[3] >= 1)) begin                 // Case 3
                    Auto_precharge[3] = 1'b0;
                    Write_precharge[3] = 1'b0;
                    RW_interrupt_write[3] = 1'b0;
                    Pc_b3 = 1'b1;
                    Act_b3 = 1'b0;
                    RP_chk3 = $time + tWRa;
                    if (Debug) begin
                        $display ("%m : at time %t NOTE : Start Internal Auto Precharge for Bank 3", $time);
                    end
            end
        end

        //  Read with Auto Precharge Calculation
        //      The device start internal precharge:
        //          1.  Meet minimum tRAS requirement
        //      and 2.  CAS Latency - 1 cycles before last burst
        //       or 3.  Interrupt by a Read or Write (with or without AutoPrecharge)
        if ((Auto_precharge[0] == 1'b1) && (Read_precharge[0] == 1'b1)) begin
            if ((($time - RAS_chk0 >= tRAS) &&                                                      // Case 1
                ((Burst_length_1 == 1'b1 && Count_precharge[0] >= 1) ||                             // Case 2
                 (Burst_length_2 == 1'b1 && Count_precharge[0] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge[0] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge[0] >= 8))) ||
                 (RW_interrupt_read[0] == 1'b1)) begin                                              // Case 3
                    Pc_b0 = 1'b1;
                    Act_b0 = 1'b0;
                    RP_chk0 = $time;
                    Auto_precharge[0] = 1'b0;
                    Read_precharge[0] = 1'b0;
                    RW_interrupt_read[0] = 1'b0;
                    if (Debug) begin
                        $display ("%m : at time %t NOTE : Start Internal Auto Precharge for Bank 0", $time);
                    end
            end
        end
        if ((Auto_precharge[1] == 1'b1) && (Read_precharge[1] == 1'b1)) begin
            if ((($time - RAS_chk1 >= tRAS) &&
                ((Burst_length_1 == 1'b1 && Count_precharge[1] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge[1] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge[1] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge[1] >= 8))) ||
                 (RW_interrupt_read[1] == 1'b1)) begin
                    Pc_b1 = 1'b1;
                    Act_b1 = 1'b0;
                    RP_chk1 = $time;
                    Auto_precharge[1] = 1'b0;
                    Read_precharge[1] = 1'b0;
                    RW_interrupt_read[1] = 1'b0;
                    if (Debug) begin
                        $display ("%m : at time %t NOTE : Start Internal Auto Precharge for Bank 1", $time);
                    end
            end
        end
        if ((Auto_precharge[2] == 1'b1) && (Read_precharge[2] == 1'b1)) begin
            if ((($time - RAS_chk2 >= tRAS) &&
                ((Burst_length_1 == 1'b1 && Count_precharge[2] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge[2] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge[2] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge[2] >= 8))) ||
                 (RW_interrupt_read[2] == 1'b1)) begin
                    Pc_b2 = 1'b1;
                    Act_b2 = 1'b0;
                    RP_chk2 = $time;
                    Auto_precharge[2] = 1'b0;
                    Read_precharge[2] = 1'b0;
                    RW_interrupt_read[2] = 1'b0;
                    if (Debug) begin
                        $display ("%m : at time %t NOTE : Start Internal Auto Precharge for Bank 2", $time);
                    end
            end
        end
        if ((Auto_precharge[3] == 1'b1) && (Read_precharge[3] == 1'b1)) begin
            if ((($time - RAS_chk3 >= tRAS) &&
                ((Burst_length_1 == 1'b1 && Count_precharge[3] >= 1) || 
                 (Burst_length_2 == 1'b1 && Count_precharge[3] >= 2) ||
                 (Burst_length_4 == 1'b1 && Count_precharge[3] >= 4) ||
                 (Burst_length_8 == 1'b1 && Count_precharge[3] >= 8))) ||
                 (RW_interrupt_read[3] == 1'b1)) begin
                    Pc_b3 = 1'b1;
                    Act_b3 = 1'b0;
                    RP_chk3 = $time;
                    Auto_precharge[3] = 1'b0;
                    Read_precharge[3] = 1'b0;
                    RW_interrupt_read[3] = 1'b0;
                    if (Debug) begin
                        $display("%m : at time %t NOTE : Start Internal Auto Precharge for Bank 3", $time);
                    end
            end
        end

        // Internal Precharge or Bst
        if (Command[0] == `PRECH) begin                         // Precharge terminate a read with same bank or all banks
            if (Bank_precharge[0] == Bank || A10_precharge[0] == 1'b1) begin
                if (Data_out_enable == 1'b1) begin
                    Data_out_enable = 1'b0;
                end
            end
        end else if (Command[0] == `BST) begin                  // BST terminate a read to current bank
            if (Data_out_enable == 1'b1) begin
                Data_out_enable = 1'b0;
            end
        end

        if (Data_out_enable == 1'b0) begin
            Dq_reg <= #tOH {data_bits{1'bz}};
        end

        // Detect Read or Write command
        if (Command[0] == `READ) begin
            Bank = Bank_addr[0];
            Col = Col_addr[0];
            Col_brst = Col_addr[0];
            case (Bank_addr[0])
                2'b00 : Row = B0_row_addr;
                2'b01 : Row = B1_row_addr;
                2'b10 : Row = B2_row_addr;
                2'b11 : Row = B3_row_addr;
            endcase
            Burst_counter = 0;
            Data_in_enable = 1'b0;
            Data_out_enable = 1'b1;
        end else if (Command[0] == `WRITE) begin
            Bank = Bank_addr[0];
            Col = Col_addr[0];
            Col_brst = Col_addr[0];
            case (Bank_addr[0])
                2'b00 : Row = B0_row_addr;
                2'b01 : Row = B1_row_addr;
                2'b10 : Row = B2_row_addr;
                2'b11 : Row = B3_row_addr;
            endcase
            Burst_counter = 0;
            Data_in_enable = 1'b1;
            Data_out_enable = 1'b0;
        end

        // DQ buffer (Driver/Receiver)
        if (Data_in_enable == 1'b1) begin                                   // Writing Data to Memory
            // Array buffer
            case (Bank)
                2'b00 : Dq_dqm = Bank0 [{Row, Col}];
                2'b01 : Dq_dqm = Bank1 [{Row, Col}];
                2'b10 : Dq_dqm = Bank2 [{Row, Col}];
                2'b11 : Dq_dqm = Bank3 [{Row, Col}];
            endcase

            // Dqm operation
            if (Dqm[0] == 1'b0) begin
                Dq_dqm [ 7 : 0] = Dq [ 7 : 0];
            end
            if (Dqm[1] == 1'b0) begin
                Dq_dqm [15 : 8] = Dq [15 : 8];
            end

            // Write to memory
            case (Bank)
                2'b00 : Bank0 [{Row, Col}] = Dq_dqm;
                2'b01 : Bank1 [{Row, Col}] = Dq_dqm;
                2'b10 : Bank2 [{Row, Col}] = Dq_dqm;
                2'b11 : Bank3 [{Row, Col}] = Dq_dqm;
            endcase

            // Display debug message
            if (Dqm !== 2'b11) begin
                // Record tWR for manual precharge
                WR_chkm [Bank] = $time;

                if (Debug) begin
                    $display("%m : at time %t WRITE: Bank = %d Row = %d, Col = %d, Data = %d", $time, Bank, Row, Col, Dq_dqm);
                end
            end else begin
                if (Debug) begin
                    $display("%m : at time %t WRITE: Bank = %d Row = %d, Col = %d, Data = Hi-Z due to DQM", $time, Bank, Row, Col);
                end
            end

            // Advance burst counter subroutine
            #tHZ Burst_decode;

        end else if (Data_out_enable == 1'b1) begin                         // Reading Data from Memory
            // Array buffer
            case (Bank)
                2'b00 : Dq_dqm = Bank0[{Row, Col}];
                2'b01 : Dq_dqm = Bank1[{Row, Col}];
                2'b10 : Dq_dqm = Bank2[{Row, Col}];
                2'b11 : Dq_dqm = Bank3[{Row, Col}];
            endcase

            // Dqm operation
            if (Dqm_reg0 [0] == 1'b1) begin
                Dq_dqm [ 7 : 0] = 8'bz;
            end
            if (Dqm_reg0 [1] == 1'b1) begin
                Dq_dqm [15 : 8] = 8'bz;
            end

            // Display debug message
            if (Dqm_reg0 !== 2'b11) begin
                Dq_reg = #tAC Dq_dqm;
                if (Debug) begin
                    $display("%m : at time %t READ : Bank = %d Row = %d, Col = %d, Data = %d", $time, Bank, Row, Col, Dq_reg);
                end
            end else begin
                Dq_reg = #tHZ {data_bits{1'bz}};
                if (Debug) begin
                    $display("%m : at time %t READ : Bank = %d Row = %d, Col = %d, Data = Hi-Z due to DQM", $time, Bank, Row, Col);
                end
            end

            // Advance burst counter subroutine
            Burst_decode;
        end
    end

    // Burst counter decode
    task Burst_decode;
        begin
            // Advance Burst Counter
            Burst_counter = Burst_counter + 1;

            // Burst Type
            if (Mode_reg[3] == 1'b0) begin                                  // Sequential Burst
                Col_temp = Col + 1;
            end else if (Mode_reg[3] == 1'b1) begin                         // Interleaved Burst
                Col_temp[2] =  Burst_counter[2] ^  Col_brst[2];
                Col_temp[1] =  Burst_counter[1] ^  Col_brst[1];
                Col_temp[0] =  Burst_counter[0] ^  Col_brst[0];
            end

            // Burst Length
            if (Burst_length_2) begin                                       // Burst Length = 2
                Col [0] = Col_temp [0];
            end else if (Burst_length_4) begin                              // Burst Length = 4
                Col [1 : 0] = Col_temp [1 : 0];
            end else if (Burst_length_8) begin                              // Burst Length = 8
                Col [2 : 0] = Col_temp [2 : 0];
            end else begin                                                  // Burst Length = FULL
                Col = Col_temp;
            end

            // Burst Read Single Write            
            if (Write_burst_mode == 1'b1) begin
                Data_in_enable = 1'b0;
            end

            // Data Counter
            if (Burst_length_1 == 1'b1) begin
                if (Burst_counter >= 1) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end else if (Burst_length_2 == 1'b1) begin
                if (Burst_counter >= 2) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end else if (Burst_length_4 == 1'b1) begin
                if (Burst_counter >= 4) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end else if (Burst_length_8 == 1'b1) begin
                if (Burst_counter >= 8) begin
                    Data_in_enable = 1'b0;
                    Data_out_enable = 1'b0;
                end
            end
        end
    endtask

    // Timing Parameters for -7E (133 MHz @ CL2)
    specify
        specparam
            tAH  =  0.8,                                        // Addr, Ba Hold Time
            tAS  =  1.5,                                        // Addr, Ba Setup Time
            tCH  =  2.5,                                        // Clock High-Level Width
            tCL  =  2.5,                                        // Clock Low-Level Width
            tCK  =  7.0,                                        // Clock Cycle Time
            tDH  =  0.8,                                        // Data-in Hold Time
            tDS  =  1.5,                                        // Data-in Setup Time
            tCKH =  0.8,                                        // CKE Hold  Time
            tCKS =  1.5,                                        // CKE Setup Time
            tCMH =  0.8,                                        // CS#, RAS#, CAS#, WE#, DQM# Hold  Time
            tCMS =  1.5;                                        // CS#, RAS#, CAS#, WE#, DQM# Setup Time
        $width    (posedge Clk,           tCH);
        $width    (negedge Clk,           tCL);
        $period   (negedge Clk,           tCK);
        $period   (posedge Clk,           tCK);
        $setuphold(posedge Clk,    Cke,   tCKS, tCKH);
        $setuphold(posedge Clk,    Cs_n,  tCMS, tCMH);
        $setuphold(posedge Clk,    Cas_n, tCMS, tCMH);
        $setuphold(posedge Clk,    Ras_n, tCMS, tCMH);
        $setuphold(posedge Clk,    We_n,  tCMS, tCMH);
        $setuphold(posedge Clk,    Addr,  tAS,  tAH);
        $setuphold(posedge Clk,    Ba,    tAS,  tAH);
        $setuphold(posedge Clk,    Dqm,   tCMS, tCMH);
        $setuphold(posedge Dq_chk, Dq,    tDS,  tDH);
    endspecify

endmodule
