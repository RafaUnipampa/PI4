`timescale 1ns/1ps

module qlearning_datapath_8way #(
    parameter Q_WIDTH     = 32,
    parameter STATE_WIDTH = 10,

    // Parametros em ponto fixo
    // alpha = 0.1  -> 100 / 1000
    // gamma = 0.9  -> 900 / 1000
    parameter signed [31:0] ALPHA       = 32'sd100,
    parameter signed [31:0] GAMMA       = 32'sd900,
    parameter signed [31:0] REWARD_HIT  = 32'sd1000,
    parameter signed [31:0] REWARD_MISS = -32'sd1000
)(
    input  wire clk,
    input  wire rst,

    // Controle vindo da FSM
    input  wire en_regs,
    input  wire wr_table,

    // Estado atual e resultado do acesso
    input  wire [STATE_WIDTH-1:0] state,
    input  wire hit,

    // Valores Q das 8 vias
    input  wire signed [Q_WIDTH-1:0] q0,
    input  wire signed [Q_WIDTH-1:0] q1,
    input  wire signed [Q_WIDTH-1:0] q2,
    input  wire signed [Q_WIDTH-1:0] q3,
    input  wire signed [Q_WIDTH-1:0] q4,
    input  wire signed [Q_WIDTH-1:0] q5,
    input  wire signed [Q_WIDTH-1:0] q6,
    input  wire signed [Q_WIDTH-1:0] q7,

    // Via escolhida pelo Q-Learning
    output reg [2:0] victim_way,

    // Escrita na Q-table
    output wire write_en,
    output wire [STATE_WIDTH-1:0] write_state,
    output wire [2:0] write_way,
    output wire signed [Q_WIDTH-1:0] write_data,

    // Sinais de debug
    output wire signed [Q_WIDTH-1:0] new_q_dbg,
    output wire [STATE_WIDTH-1:0] state_d3_dbg,
    output wire [2:0] action_d3_dbg
);

    // ============================================================
    // Funcao aproximada para dividir por 1000
    // ============================================================
    //
    // No projeto antigo, a divisao por 1000 gerava lpm_divide.
    // Aqui mantemos a otimizacao usando shifts e somas:
    //
    // x / 1000 aproximadamente (x * 4195) >> 22
    //
    // 4195 = 4096 + 64 + 32 + 2 + 1
    // ============================================================

    function signed [Q_WIDTH-1:0] div1000_approx;
        input signed [63:0] x;

        reg sign;
        reg [63:0] abs_x;
        reg [95:0] mult;
        reg signed [Q_WIDTH-1:0] result_temp;

        begin
            sign = x[63];

            if (sign) begin
                abs_x = -x;
            end else begin
                abs_x = x;
            end

            mult = ({32'd0, abs_x} << 12) +
                   ({32'd0, abs_x} << 6)  +
                   ({32'd0, abs_x} << 5)  +
                   ({32'd0, abs_x} << 1)  +
                   ({32'd0, abs_x});

            result_temp = mult >> 22;

            if (sign) begin
                div1000_approx = -result_temp;
            end else begin
                div1000_approx = result_temp;
            end
        end
    endfunction

    // ============================================================
    // Escolha da melhor acao entre as 8 vias
    // ============================================================

    reg [2:0] action_comb;
    reg signed [Q_WIDTH-1:0] best_next_comb;
    reg signed [Q_WIDTH-1:0] old_q_comb;

    always @(*) begin
        action_comb    = 3'd0;
        best_next_comb = q0;
        old_q_comb     = q0;

        if (q1 > best_next_comb) begin
            best_next_comb = q1;
            action_comb    = 3'd1;
        end

        if (q2 > best_next_comb) begin
            best_next_comb = q2;
            action_comb    = 3'd2;
        end

        if (q3 > best_next_comb) begin
            best_next_comb = q3;
            action_comb    = 3'd3;
        end

        if (q4 > best_next_comb) begin
            best_next_comb = q4;
            action_comb    = 3'd4;
        end

        if (q5 > best_next_comb) begin
            best_next_comb = q5;
            action_comb    = 3'd5;
        end

        if (q6 > best_next_comb) begin
            best_next_comb = q6;
            action_comb    = 3'd6;
        end

        if (q7 > best_next_comb) begin
            best_next_comb = q7;
            action_comb    = 3'd7;
        end

        case (action_comb)
            3'd0: old_q_comb = q0;
            3'd1: old_q_comb = q1;
            3'd2: old_q_comb = q2;
            3'd3: old_q_comb = q3;
            3'd4: old_q_comb = q4;
            3'd5: old_q_comb = q5;
            3'd6: old_q_comb = q6;
            3'd7: old_q_comb = q7;
            default: old_q_comb = q0;
        endcase
    end

    // ============================================================
    // Pipeline interno
    // ============================================================
    //
    // Precisamos atrasar estado e acao para que, quando new_q estiver
    // pronto, saibamos qual estado e qual via atualizar.
    // ============================================================

    reg signed [Q_WIDTH-1:0] old_q_s1;
    reg signed [Q_WIDTH-1:0] best_next_s1;
    reg signed [Q_WIDTH-1:0] reward_s1;
    reg [STATE_WIDTH-1:0] state_s1;
    reg [2:0] action_s1;

    reg signed [Q_WIDTH-1:0] target_s2;
    reg signed [Q_WIDTH-1:0] old_q_s2;
    reg [STATE_WIDTH-1:0] state_s2;
    reg [2:0] action_s2;

    reg signed [Q_WIDTH-1:0] new_q_s3;
    reg [STATE_WIDTH-1:0] state_s3;
    reg [2:0] action_s3;

    wire signed [63:0] gamma_mult;
    wire signed [Q_WIDTH-1:0] diff_s2;
    wire signed [63:0] alpha_mult;

    assign gamma_mult = $signed(best_next_s1) * $signed(GAMMA);
    assign diff_s2    = target_s2 - old_q_s2;
    assign alpha_mult = $signed(diff_s2) * $signed(ALPHA);

    always @(posedge clk) begin
        if (rst) begin
            victim_way <= 3'd0;

            old_q_s1      <= {Q_WIDTH{1'b0}};
            best_next_s1  <= {Q_WIDTH{1'b0}};
            reward_s1     <= {Q_WIDTH{1'b0}};
            state_s1      <= {STATE_WIDTH{1'b0}};
            action_s1     <= 3'd0;

            target_s2     <= {Q_WIDTH{1'b0}};
            old_q_s2      <= {Q_WIDTH{1'b0}};
            state_s2      <= {STATE_WIDTH{1'b0}};
            action_s2     <= 3'd0;

            new_q_s3      <= {Q_WIDTH{1'b0}};
            state_s3      <= {STATE_WIDTH{1'b0}};
            action_s3     <= 3'd0;

        end else begin
            if (en_regs) begin

                // Estagio 1:
                // escolhe a acao e captura os valores principais
                old_q_s1     <= old_q_comb;
                best_next_s1 <= best_next_comb;
                reward_s1    <= hit ? REWARD_HIT : REWARD_MISS;
                state_s1     <= state;
                action_s1    <= action_comb;

                victim_way <= action_comb;

                // Estagio 2:
                // target = reward + gamma * best_next
                target_s2 <= reward_s1 + div1000_approx(gamma_mult);
                old_q_s2  <= old_q_s1;
                state_s2  <= state_s1;
                action_s2 <= action_s1;

                // Estagio 3:
                // new_q = old_q + alpha * (target - old_q)
                new_q_s3 <= old_q_s2 + div1000_approx(alpha_mult);
                state_s3 <= state_s2;
                action_s3 <= action_s2;
            end
        end
    end

    // ============================================================
    // Saidas para escrita na Q-table
    // ============================================================

    assign write_en    = wr_table;
    assign write_state = state_s3;
    assign write_way   = action_s3;
    assign write_data  = new_q_s3;

    // ============================================================
    // Debug
    // ============================================================

    assign new_q_dbg     = new_q_s3;
    assign state_d3_dbg  = state_s3;
    assign action_d3_dbg = action_s3;

endmodule