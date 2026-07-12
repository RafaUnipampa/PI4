`timescale 1ns/1ps

module tb_qlearning_datapath;

    reg clk;
    reg rst;

    reg en_regs;
    reg wr_table;

    reg signed [31:0] q0;
    reg signed [31:0] q1;
    reg [9:0] state;
    reg hit;

    wire victim_way;

    wire action_reg;
    wire signed [31:0] old_q_reg;
    wire signed [31:0] best_next_reg;

    wire signed [31:0] target_reg;
    wire signed [31:0] diff_reg;
    wire signed [31:0] new_q_reg;

    wire [9:0] state_reg;
    wire [9:0] state_d1;
    wire [9:0] state_d2;
    wire [9:0] state_d3;

    wire action_d1;
    wire action_d2;
    wire action_d3;

    wire wr_way0;
    wire wr_way1;

    qlearning_datapath dut (
        .clk(clk),
        .rst(rst),

        .en_regs(en_regs),
        .wr_table(wr_table),

        .q0(q0),
        .q1(q1),
        .state(state),
        .hit(hit),

        .victim_way(victim_way),

        .action_reg(action_reg),
        .old_q_reg(old_q_reg),
        .best_next_reg(best_next_reg),

        .target_reg(target_reg),
        .diff_reg(diff_reg),
        .new_q_reg(new_q_reg),

        .state_reg(state_reg),
        .state_d1(state_d1),
        .state_d2(state_d2),
        .state_d3(state_d3),

        .action_d1(action_d1),
        .action_d2(action_d2),
        .action_d3(action_d3),

        .wr_way0(wr_way0),
        .wr_way1(wr_way1)
    );

    always #5 clk = ~clk;

    task print_status;
        begin
            $display("--------------------------------------------------");
            $display("q0=%0d q1=%0d state=%0d hit=%b", q0, q1, state, hit);
            $display("victim_way=%b action_reg=%b action_d1=%b action_d2=%b action_d3=%b",
                     victim_way, action_reg, action_d1, action_d2, action_d3);
            $display("state_reg=%0d state_d1=%0d state_d2=%0d state_d3=%0d",
                     state_reg, state_d1, state_d2, state_d3);
            $display("old_q=%0d best_next=%0d", old_q_reg, best_next_reg);
            $display("target=%0d diff=%0d new_q=%0d", target_reg, diff_reg, new_q_reg);
            $display("wr_table=%b wr_way0=%b wr_way1=%b", wr_table, wr_way0, wr_way1);
            $display("HEX: target=%h diff=%h new_q=%h", target_reg, diff_reg, new_q_reg);
        end
    endtask

    task reset_circuit;
        begin
            rst = 1;
            en_regs = 0;
            wr_table = 0;
            q0 = 0;
            q1 = 0;
            state = 0;
            hit = 0;

            #12;
            rst = 0;
            en_regs = 1;
        end
    endtask

    initial begin
        $dumpfile("tb_qlearning_datapath.vcd");
        $dumpvars(0, tb_qlearning_datapath);

        clk = 0;

        // ==================================================
        // TESTE 1: q0 > q1
        // Esperado:
        // victim_way = 0
        // action_d3 = 0
        // wr_way0 = 1 quando wr_table = 1
        // old_q = 10
        // best_next = 10
        // target = 1009
        // diff = 999
        // new_q = 109 = 0x0000006D
        // ==================================================

        $display("\nTESTE 1: q0 maior que q1, deve escolher via 0");

        reset_circuit();

        q0 = 32'd10;
        q1 = 32'd5;
        state = 10'd5;
        hit = 1'b1;
        wr_table = 1'b0;

        repeat(6) @(posedge clk);

        wr_table = 1'b1;
        #1;

        print_status();

        if(victim_way !== 1'b0)
            $display("ERRO: victim_way deveria ser 0");
        else
            $display("OK: victim_way = 0");

        if(action_d3 !== 1'b0)
            $display("ERRO: action_d3 deveria ser 0");
        else
            $display("OK: action_d3 = 0");

        if(wr_way0 !== 1'b1 || wr_way1 !== 1'b0)
            $display("ERRO: deveria escrever somente na via 0");
        else
            $display("OK: write back selecionou via 0");

        if(new_q_reg !== 32'd109)
            $display("ERRO: new_q deveria ser 109");
        else
            $display("OK: new_q = 109");

        wr_table = 1'b0;

        // ==================================================
        // TESTE 2: q1 > q0
        // Esperado:
        // victim_way = 1
        // action_d3 = 1
        // wr_way1 = 1 quando wr_table = 1
        // old_q = 15
        // best_next = 15
        // target = 1013
        // diff = 998
        // new_q = 114 = 0x00000072
        // ==================================================

        $display("\nTESTE 2: q1 maior que q0, deve escolher via 1");

        reset_circuit();

        q0 = 32'd10;
        q1 = 32'd15;
        state = 10'd6;
        hit = 1'b1;
        wr_table = 1'b0;

        repeat(6) @(posedge clk);

        wr_table = 1'b1;
        #1;

        print_status();

        if(victim_way !== 1'b1)
            $display("ERRO: victim_way deveria ser 1");
        else
            $display("OK: victim_way = 1");

        if(action_d3 !== 1'b1)
            $display("ERRO: action_d3 deveria ser 1");
        else
            $display("OK: action_d3 = 1");

        if(wr_way0 !== 1'b0 || wr_way1 !== 1'b1)
            $display("ERRO: deveria escrever somente na via 1");
        else
            $display("OK: write back selecionou via 1");

        if(new_q_reg !== 32'd114)
            $display("ERRO: new_q deveria ser 114");
        else
            $display("OK: new_q = 114");

        wr_table = 1'b0;

        // ==================================================
        // TESTE 3: empate q0 == q1
        // No C usamos if(q1 > q0), então empate escolhe via 0.
        // ==================================================

        $display("\nTESTE 3: empate, deve escolher via 0");

        reset_circuit();

        q0 = 32'd10;
        q1 = 32'd10;
        state = 10'd7;
        hit = 1'b1;
        wr_table = 1'b0;

        repeat(6) @(posedge clk);

        wr_table = 1'b1;
        #1;

        print_status();

        if(victim_way !== 1'b0)
            $display("ERRO: em empate victim_way deveria ser 0");
        else
            $display("OK: empate escolheu via 0");

        if(wr_way0 !== 1'b1 || wr_way1 !== 1'b0)
            $display("ERRO: em empate deveria escrever na via 0");
        else
            $display("OK: write back selecionou via 0 no empate");

        $display("\nSIMULACAO FINALIZADA.");
        $finish;
    end

endmodule