`timescale 1ns/1ps

module tb_qlearning_top;

    reg clk;
    reg rst;

    reg en_regs;
    reg wr_table;

    reg [9:0] state;
    reg hit;

    wire victim_way;

    wire signed [31:0] q0_dbg;
    wire signed [31:0] q1_dbg;
    wire signed [31:0] new_q_dbg;

    wire [9:0] state_d3_dbg;
    wire action_d3_dbg;

    wire wr_way0_dbg;
    wire wr_way1_dbg;

    qlearning_top dut (
        .clk(clk),
        .rst(rst),

        .en_regs(en_regs),
        .wr_table(wr_table),

        .state(state),
        .hit(hit),

        .victim_way(victim_way),

        .q0_dbg(q0_dbg),
        .q1_dbg(q1_dbg),

        .new_q_dbg(new_q_dbg),
        .state_d3_dbg(state_d3_dbg),
        .action_d3_dbg(action_d3_dbg),

        .wr_way0_dbg(wr_way0_dbg),
        .wr_way1_dbg(wr_way1_dbg)
    );

    always #5 clk = ~clk;

    task reset_datapath;
        begin
            rst = 1;
            en_regs = 0;
            wr_table = 0;
            state = 0;
            hit = 0;

            #12;
            rst = 0;
            en_regs = 1;
        end
    endtask

    task print_status;
        begin
            $display("--------------------------------------------------");
            $display("state=%0d hit=%b", state, hit);
            $display("q0=%0d q1=%0d", q0_dbg, q1_dbg);
            $display("victim_way=%b action_d3=%b state_d3=%0d",
                     victim_way, action_d3_dbg, state_d3_dbg);
            $display("new_q=%0d HEX=%h", new_q_dbg, new_q_dbg);
            $display("wr_table=%b wr_way0=%b wr_way1=%b",
                     wr_table, wr_way0_dbg, wr_way1_dbg);
        end
    endtask

    initial begin
        $dumpfile("tb_qlearning_top.vcd");
        $dumpvars(0, tb_qlearning_top);

        clk = 0;

        // ==================================================
        // TESTE 1:
        // Q-table começa zerada no estado 5.
        // q0 = 0, q1 = 0, empate escolhe via 0.
        // hit = 1 => reward = 1000.
        // new_q esperado = 100.
        // Deve escrever em q_way0[5].
        // ==================================================

        $display("\nTESTE 1: Q-table zerada, empate deve escrever na via 0");

        reset_datapath();

        state = 10'd5;
        hit = 1'b1;
        wr_table = 1'b0;

        repeat(6) @(posedge clk);

        wr_table = 1'b1;
        @(posedge clk);
        #1;
        wr_table = 1'b0;

        print_status();

        if (dut.qtable_inst.q_way0[5] == 32'd100 && dut.qtable_inst.q_way1[5] == 32'd0)
            $display("OK: escreveu new_q=100 somente em q_way0[5]");
        else
            $display("ERRO: escrita no estado 5 falhou. q_way0[5]=%0d q_way1[5]=%0d",
                     dut.qtable_inst.q_way0[5], dut.qtable_inst.q_way1[5]);

        // ==================================================
        // TESTE 2:
        // Pré-carrega estado 6:
        // q_way0[6] = 10
        // q_way1[6] = 15
        // Como q1 > q0, deve escolher via 1.
        // new_q esperado = 114.
        // Deve escrever em q_way1[6].
        // ==================================================

        $display("\nTESTE 2: q1 maior que q0, deve escrever na via 1");

        reset_datapath();

        dut.qtable_inst.q_way0[6] = 32'sd10;
        dut.qtable_inst.q_way1[6] = 32'sd15;

        state = 10'd6;
        hit = 1'b1;
        wr_table = 1'b0;

        repeat(6) @(posedge clk);

        wr_table = 1'b1;
        @(posedge clk);
        #1;
        wr_table = 1'b0;

        print_status();

        if (dut.qtable_inst.q_way0[6] == 32'd10 && dut.qtable_inst.q_way1[6] == 32'd114)
            $display("OK: escreveu new_q=114 somente em q_way1[6]");
        else
            $display("ERRO: escrita no estado 6 falhou. q_way0[6]=%0d q_way1[6]=%0d",
                     dut.qtable_inst.q_way0[6], dut.qtable_inst.q_way1[6]);

        // ==================================================
        // TESTE 3:
        // Pré-carrega estado 7:
        // q_way0[7] = 10
        // q_way1[7] = 10
        // Empate deve escolher via 0.
        // new_q esperado = 109.
        // Deve escrever em q_way0[7].
        // ==================================================

        $display("\nTESTE 3: empate, deve escrever na via 0");

        reset_datapath();

        dut.qtable_inst.q_way0[7] = 32'sd10;
        dut.qtable_inst.q_way1[7] = 32'sd10;

        state = 10'd7;
        hit = 1'b1;
        wr_table = 1'b0;

        repeat(6) @(posedge clk);

        wr_table = 1'b1;
        @(posedge clk);
        #1;
        wr_table = 1'b0;

        print_status();

        if (dut.qtable_inst.q_way0[7] == 32'd109 && dut.qtable_inst.q_way1[7] == 32'd10)
            $display("OK: empate escreveu new_q=109 somente em q_way0[7]");
        else
            $display("ERRO: escrita no estado 7 falhou. q_way0[7]=%0d q_way1[7]=%0d",
                     dut.qtable_inst.q_way0[7], dut.qtable_inst.q_way1[7]);

        $display("\nSIMULACAO DO TOP FINALIZADA.");
        $finish;
    end

endmodule   