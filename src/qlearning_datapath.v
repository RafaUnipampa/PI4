module qlearning_datapath #(
    parameter Q_WIDTH = 32,
    parameter STATE_WIDTH = 10,
    parameter SCALE = 1000,
    parameter ALPHA = 100,
    parameter GAMMA = 900,
    parameter REWARD_HIT = 1000,
    parameter REWARD_MISS = -1000
)(
    input  wire clk,
    input  wire rst,

    input  wire en_regs,
    input  wire wr_table,

    input  wire signed [Q_WIDTH-1:0] q0,
    input  wire signed [Q_WIDTH-1:0] q1,
    input  wire [STATE_WIDTH-1:0] state,
    input  wire hit,

    output wire victim_way,

    output reg action_reg,
    output reg signed [Q_WIDTH-1:0] old_q_reg,
    output reg signed [Q_WIDTH-1:0] best_next_reg,

    output reg signed [Q_WIDTH-1:0] target_reg,
    output reg signed [Q_WIDTH-1:0] diff_reg,
    output reg signed [Q_WIDTH-1:0] new_q_reg,

    output reg [STATE_WIDTH-1:0] state_reg,
    output reg [STATE_WIDTH-1:0] state_d1,
    output reg [STATE_WIDTH-1:0] state_d2,
    output reg [STATE_WIDTH-1:0] state_d3,

    output reg action_d1,
    output reg action_d2,
    output reg action_d3,

    output wire wr_way0,
    output wire wr_way1
);

    wire action_sel;

    wire signed [Q_WIDTH-1:0] reward;
    wire signed [Q_WIDTH-1:0] old_q_comb;
    wire signed [Q_WIDTH-1:0] best_next_comb;

    reg signed [Q_WIDTH-1:0] target_comb;
    reg signed [Q_WIDTH-1:0] diff_comb;
    reg signed [Q_WIDTH-1:0] new_q_comb;

    reg signed [63:0] mult_gamma_best;
    reg signed [63:0] mult_alpha_diff;

    // ============================================================
    // Aproximacao de divisao por 1000
    // ------------------------------------------------------------
    // No datapath antigo, tinhamos:
    //
    //     valor / SCALE
    //
    // com SCALE = 1000.
    //
    // O problema e que o Quartus inferia divisores combinacionais
    // lpm_divide, que sao pesados em FPGA e prejudicam o timing.
    //
    // Aqui usamos:
    //
    //     1/1000 aproximadamente igual a 4195 / 2^22
    //
    // Como:
    //
    //     4195 = 4096 + 64 + 32 + 2 + 1
    //
    // entao:
    //
    //     x / 1000 aproximadamente
    //     (x*4096 + x*64 + x*32 + x*2 + x) >> 22
    //
    // Isso troca divisao por shifts e somas.
    // ============================================================

    function signed [Q_WIDTH-1:0] div1000_approx;
        input signed [63:0] x;

        reg neg;
        reg [63:0] abs_x;
        reg [95:0] scaled;
        reg [95:0] quotient;

        begin
            if (x < 0) begin
                neg = 1'b1;
                abs_x = -x;
            end else begin
                neg = 1'b0;
                abs_x = x;
            end

            scaled =
                ({32'd0, abs_x} << 12) +  // x * 4096
                ({32'd0, abs_x} << 6)  +  // x * 64
                ({32'd0, abs_x} << 5)  +  // x * 32
                ({32'd0, abs_x} << 1)  +  // x * 2
                ({32'd0, abs_x});         // x * 1

            quotient = scaled >> 22;

            if (neg)
                div1000_approx = -$signed(quotient[Q_WIDTH-1:0]);
            else
                div1000_approx = $signed(quotient[Q_WIDTH-1:0]);
        end
    endfunction

    // Equivalente ao trecho C:
    // if(q1 > q0) best_way = 1;
    // else        best_way = 0;
    assign action_sel = (q1 > q0) ? 1'b1 : 1'b0;

    // Sinal enviado para a L1 Cache
    assign victim_way = action_sel;

    // Reward Generator
    assign reward = hit ? REWARD_HIT : REWARD_MISS;

    // Old Q MUX
    assign old_q_comb = action_sel ? q1 : q0;

    // Max q0 q1
    assign best_next_comb = action_sel ? q1 : q0;

    // Controle de escrita da Q-table
    assign wr_way0 = wr_table & (~action_d3);
    assign wr_way1 = wr_table & action_d3;

    always @(*) begin
        // Antes:
        // target_comb = reward + (mult_gamma_best / SCALE);
        //
        // Agora:
        // target_comb = reward + div1000_approx(mult_gamma_best);

        mult_gamma_best = $signed(best_next_reg) * GAMMA;
        target_comb = reward + div1000_approx(mult_gamma_best);

        diff_comb = target_reg - old_q_reg;

        // Antes:
        // new_q_comb = old_q_reg + (mult_alpha_diff / SCALE);
        //
        // Agora:
        // new_q_comb = old_q_reg + div1000_approx(mult_alpha_diff);

        mult_alpha_diff = $signed(diff_reg) * ALPHA;
        new_q_comb = old_q_reg + div1000_approx(mult_alpha_diff);
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            action_reg <= 1'b0;
            old_q_reg <= 0;
            best_next_reg <= 0;

            target_reg <= 0;
            diff_reg <= 0;
            new_q_reg <= 0;

            state_reg <= 0;
            state_d1 <= 0;
            state_d2 <= 0;
            state_d3 <= 0;

            action_d1 <= 1'b0;
            action_d2 <= 1'b0;
            action_d3 <= 1'b0;
        end else if (en_regs) begin
            // Estagio 1: decisao e preparacao
            action_reg <= action_sel;
            old_q_reg <= old_q_comb;
            best_next_reg <= best_next_comb;
            state_reg <= state;

            // Pipeline da acao
            action_d1 <= action_reg;
            action_d2 <= action_d1;
            action_d3 <= action_d2;

            // Pipeline do estado
            state_d1 <= state_reg;
            state_d2 <= state_d1;
            state_d3 <= state_d2;

            // Estagio 2: Target Calc
            target_reg <= target_comb;

            // Estagio 3: Diff Calc
            diff_reg <= diff_comb;

            // Estagio 4: New Q Calc
            new_q_reg <= new_q_comb;
        end
    end

endmodule