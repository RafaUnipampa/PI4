`timescale 1ns/1ps

module tb_qlearning_system;

    reg clk;
    reg rst;
    reg start;

    reg [9:0] state;
    reg hit;

    wire busy;
    wire done;
    wire victim_way;

    wire signed [31:0] q0_dbg;
    wire signed [31:0] q1_dbg;
    wire signed [31:0] new_q_dbg;

    wire [9:0] state_d3_dbg;
    wire action_d3_dbg;

    wire wr_way0_dbg;
    wire wr_way1_dbg;

    wire en_regs_dbg;
    wire wr_table_dbg;

    qlearning_system dut (
        .clk(clk),
        .rst(rst),
        .start(start),

        .state(state),
        .hit(hit),

        .busy(busy),
        .done(done),
        .victim_way(victim_way),

        .q0_dbg(q0_dbg),
        .q1_dbg(q1_dbg),
        .new_q_dbg(new_q_dbg),

        .state_d3_dbg(state_d3_dbg),
        .action_d3_dbg(action_d3_dbg),

        .wr_way0_dbg(wr_way0_dbg),
        .wr_way1_dbg(wr_way1_dbg),

        .en_regs_dbg(en_regs_dbg),
        .wr_table_dbg(wr_table_dbg)
    );

    always #5 clk = ~clk;

    task reset_system;
        begin
            rst = 1;
            start = 0;
            state = 0;
            hit = 0;

            #20;
            rst = 0;
            #10;
        end
    endtask

    task run_update;
        input [9:0] st;
        input hit_value;
        begin
            state = st;
            hit = hit_value;

            @(negedge clk);
            start = 1;

            @(negedge clk);
            start = 0;

            wait(done == 1);
            #1;
        end
    endtask

    task print_status;
        begin
            $display("--------------------------------------------------");
            $display("state=%0d hit=%b", state, hit);
            $display("q0_dbg=%0d q1_dbg=%0d", q0_dbg, q1_dbg);
            $display("victim_way=%b action_d3=%b state_d3=%0d",
                     victim_way, action_d3_dbg, state_d3_dbg);
            $display("new_q=%0d HEX=%h", new_q_dbg, new_q_dbg);
            $display("busy=%b done=%b en_regs=%b wr_table=%b",
                     busy, done, en_regs_dbg, wr_table_dbg);
            $display("wr_way0=%b wr_way1=%b", wr_way0_dbg, wr_way1_dbg);
        end
    endtask

    initial begin
        $dumpfile("tb_qlearning_system.vcd");
        $dumpvars(0, tb_qlearning_system);

        clk = 0;

        reset_system();

        // ==================================================
        // TESTE 1
        // Q-table zerada no estado 5.
        // q0 = 0, q1 = 0.
        // Empate escolhe via 0.
        // hit = 1.
        // new_q esperado = 100.
        // Deve escrever em q_way0[5].
        // ==================================================

        $display("\nTESTE 1: Q-table zerada, empate escreve na via 0");

        run_update(10'd5, 1'b1);
        print_status();

        if (dut.top_inst.qtable_inst.q_way0[5] == 32'd100 &&
            dut.top_inst.qtable_inst.q_way1[5] == 32'd0)
            $display("OK: escreveu 100 somente em q_way0[5]");
        else
            $display("ERRO: q_way0[5]=%0d q_way1[5]=%0d",
                     dut.top_inst.qtable_inst.q_way0[5],
                     dut.top_inst.qtable_inst.q_way1[5]);

        @(posedge clk);

        // ==================================================
        // TESTE 2
        // Pré-carrega estado 6:
        // q_way0[6] = 10
        // q_way1[6] = 15
        // Como q1 > q0, escolhe via 1.
        // new_q esperado = 114.
        // Deve escrever em q_way1[6].
        // ==================================================

        $display("\nTESTE 2: q1 maior que q0, escreve na via 1");

        dut.top_inst.qtable_inst.q_way0[6] = 32'sd10;
        dut.top_inst.qtable_inst.q_way1[6] = 32'sd15;

        run_update(10'd6, 1'b1);
        print_status();

        if (dut.top_inst.qtable_inst.q_way0[6] == 32'd10 &&
            dut.top_inst.qtable_inst.q_way1[6] == 32'd114)
            $display("OK: escreveu 114 somente em q_way1[6]");
        else
            $display("ERRO: q_way0[6]=%0d q_way1[6]=%0d",
                     dut.top_inst.qtable_inst.q_way0[6],
                     dut.top_inst.qtable_inst.q_way1[6]);

        @(posedge clk);

        // ==================================================
        // TESTE 3
        // Pré-carrega estado 7:
        // q_way0[7] = 10
        // q_way1[7] = 10
        // Empate escolhe via 0.
        // new_q esperado = 109.
        // Deve escrever em q_way0[7].
        // ==================================================

        $display("\nTESTE 3: empate escreve na via 0");

        dut.top_inst.qtable_inst.q_way0[7] = 32'sd10;
        dut.top_inst.qtable_inst.q_way1[7] = 32'sd10;

        run_update(10'd7, 1'b1);
        print_status();

        if (dut.top_inst.qtable_inst.q_way0[7] == 32'd109 &&
            dut.top_inst.qtable_inst.q_way1[7] == 32'd10)
            $display("OK: empate escreveu 109 somente em q_way0[7]");
        else
            $display("ERRO: q_way0[7]=%0d q_way1[7]=%0d",
                     dut.top_inst.qtable_inst.q_way0[7],
                     dut.top_inst.qtable_inst.q_way1[7]);

        $display("\nSIMULACAO DO SISTEMA COMPLETO FINALIZADA.");
        $finish;
    end

endmodule   