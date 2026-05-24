typedef struct packed {
  logic [19:0] [3:0] digits;
} digitosPac_t;

module decodificador_de_teclado (
  input   logic       clk,
  input   logic       rst,
  input   logic       enable,
  input   logic [3:0] col_matriz,
  output  logic [3:0] lin_matriz,
  output  digitosPac_t  digitos_value,
  output  logic       digitos_valid
);

  logic [3:0] col_lida;
  logic c0;
  logic c1;
  logic [3:0] tecla_lida;
  logic nova_tecla;
  
  // REGRA DO ICARUS: Enums precisam de valores inteiros explícitos atribuidos para simulação estável
  typedef enum logic [3:0] {
    leitura           = 4'd0,
    db                = 4'd1,
    decodificar       = 4'd2,
    arrayValido       = 4'd3,
    arrayComB_up      = 4'd4,
    arrayComB_down    = 4'd5,
    arrayComE_up      = 4'd6,
    arrayComE_down    = 4'd7,
    limparArray       = 4'd8,
    reset             = 4'd9,
    inserirNoArray    = 4'd10,
    tecladoDesativado = 4'd11
  } estado_t;

  estado_t estado;

  logic [12:0] ta; // 0 - 8191
  logic [6:0] td;  // 0 - 127
  
  // Registrador interno plano para contornar limitações de atribuição do shifter no Icarus
  logic [79:0] barramento_reg;

  assign c0 = (col_matriz == 4'b0111 || col_matriz == 4'b1011 || col_matriz == 4'b1101 || col_matriz == 4'b1110);
  assign c1 = (col_matriz == 4'b1111);

  // Lógica de Próximo Estado e Caminho de Dados Sequencial
  always_ff @(posedge rst or posedge clk) begin
      if (rst) begin
        estado         <= leitura;
        ta             <= 0;
        td             <= 0;
        lin_matriz     <= 4'b0111;
        barramento_reg <= {20{4'hF}}; // Inicializa tudo limpo (0xF)
      end else begin
        case (estado)

          reset: begin
            ta             <= 0;
            td             <= 0;
            barramento_reg <= {20{4'hF}};
            estado         <= leitura;
          end
          
          leitura: begin
            ta <= ta + 1;
            if (c0) begin
              col_lida <= col_matriz;
              td       <= 0;
              estado   <= db;
            end
            else if (ta >= 5000) begin
                estado <= arrayComE_up;
            end
            else if (!enable) begin
                estado <= tecladoDesativado;
            end
            else begin
              case(lin_matriz)
                4'b0111: lin_matriz <= 4'b1011;
                4'b1011: lin_matriz <= 4'b1101;
                4'b1101: lin_matriz <= 4'b1110;
                4'b1110: lin_matriz <= 4'b0111;
                default: lin_matriz <= 4'b0111;
              endcase
            end
          end
          
          db: begin
            td <= td + 1;
            if (c1) begin
                ta     <= 0;
                estado <= leitura;
            end
            else if (td >= 100) begin
                estado <= decodificar;
            end
          end
          
          decodificar: begin
            td <= 0;
            if (((lin_matriz << 4) | col_matriz) == 8'b11100111) begin
                estado <= arrayValido;
            end
            else if (((lin_matriz << 4) | col_matriz) == 8'b11101101) begin
                estado <= arrayComB_up;
            end
            else begin
                estado <= inserirNoArray;
            end
          end
          
          arrayValido: begin
            td     <= 0;
            estado <= limparArray;
          end
          
          arrayComB_up: begin
            td             <= 0;
            barramento_reg <= {20{4'hB}}; // Força o preenchimento de Bs
            estado         <= arrayComB_down;
          end
          
          arrayComB_down: begin
            td     <= 0;
            estado <= limparArray;
          end
          
          arrayComE_up: begin
            td             <= 0;
            barramento_reg <= {20{4'hE}}; // Força o preenchimento de Es
            estado         <= arrayComE_down;
          end
          
          arrayComE_down: begin
            td     <= 0;
            estado <= limparArray;
          end
          
          limparArray: begin
            if (c1) begin
                ta             <= 0;
                barramento_reg <= {20{4'hF}}; // Reseta o barramento após o envio
                estado         <= leitura;
            end
          end
          
          inserirNoArray: begin
            if (c1) begin
                ta <= 0;
                // Deslocamento de 4 bits plano (Shifter refeito de forma segura e paralela para o hardware)
                if (nova_tecla) begin
                    barramento_reg <= {barramento_reg[75:0], tecla_lida};
                end
                estado <= leitura;
            end
          end
          
          tecladoDesativado: begin
            if (enable) begin
                estado <= leitura;
            end
          end
          
          default: begin
            td         <= 0;
            ta         <= 0;
            estado     <= leitura;
            lin_matriz <= 4'b0111;
          end
        endcase
      end
  end

  // Geração do sinal digitos_valid
  always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
           digitos_valid <= 0;
        end else begin
           if ((estado == arrayComB_up) || (estado == arrayComE_up) || (estado == arrayValido)) begin
              digitos_valid <= 1;
           end
           else begin
              digitos_valid <= 0;
           end
        end
  end

  // Bloco Combinacional Corrigido (Sem Latches e Compatível com o Interpretador)
  always_comb begin
    // Valores padrão para evitar latches implícitos no combinacional
    tecla_lida = 4'hF;
    nova_tecla = 0;

    case (estado)
      decodificar: begin
        case ((lin_matriz << 4) | col_lida)
          8'b01110111: begin tecla_lida = 4'h1; nova_tecla = 1; end
          8'b01111011: begin tecla_lida = 4'h2; nova_tecla = 1; end
          8'b01111101: begin tecla_lida = 4'h3; nova_tecla = 1; end

          8'b10110111: begin tecla_lida = 4'h4; nova_tecla = 1; end
          8'b10111011: begin tecla_lida = 4'h5; nova_tecla = 1; end
          8'b10111101: begin tecla_lida = 4'h6; nova_tecla = 1; end

          8'b11010111: begin tecla_lida = 4'h7; nova_tecla = 1; end
          8'b11011011: begin tecla_lida = 4'h8; nova_tecla = 1; end
          8'b11011101: begin tecla_lida = 4'h9; nova_tecla = 1; end

          8'b11101011: begin tecla_lida = 4'h0; nova_tecla = 1; end
          default: begin
              tecla_lida = 4'hF;
              nova_tecla = 0;
          end
        endcase
      end
      
      default: begin
        tecla_lida = 4'hF;
        nova_tecla = 0;
      end
    endcase
  end

  // Atribuição contínua da saída do módulo baseada no registrador interno estável
  assign digitos_value = barramento_reg;

endmodule