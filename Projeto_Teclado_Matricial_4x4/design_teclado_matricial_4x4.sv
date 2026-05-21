//------------------------------------------------------------------------------------------------------------------------
//------------------------------MÓDULO DECODIFICADOR DE TECLADO-----------------------------------------------------------
//------------------------------------------------------------------------------------------------------------------------

typedef struct packed {
    logic [19:0] [3:0] digits;
} senhaPac_t;

module decodificador_de_teclado (
    input        logic        clk,
    input        logic        rst,
    input        logic        enable,
    input        logic [3:0]  col_matriz,
    output       logic [3:0]  lin_matriz,
    output       senhaPac_t   digitos_value,
    output       logic        digitos_valid
);

  logic [3:0] col_lida;
  logic c0;
  logic c1;
  logic [3:0] tecla_lida;
  logic nova_tecla;
  
  typedef enum logic [3:0] {
    leitura,
    db,
    decodificar,
    arrayValido,
    arrayComB_up,
    arrayComB_down,
    arrayComE_up,
    arrayComE_down,
    limparArray,
    reset,
    inserirNoArray,
    tecladoDesativado
  } estado_t;
  
  estado_t estado;

  logic [12:0] ta;
  logic [6:0] td; // 0 - 127
  
  // Variável auxiliar para ajudar o Icarus na decodificação do case
  logic [7:0] barramento_composto;
  assign barramento_composto = {lin_matriz, col_lida};

  assign c0 = (col_matriz == 4'b0111 || col_matriz == 4'b1011 || col_matriz == 4'b1101 || col_matriz == 4'b1110);
  assign c1 = (col_matriz == 4'b1111);

  // Bloco de controle de Estado e Registradores
  always_ff @(posedge rst or posedge clk) begin
      if (rst) begin
        estado        <= leitura;
        lin_matriz    <= 4'b0111;
        col_lida      <= 4'b1111;
        ta            <= 0;
        td            <= 0;
        digitos_value <= 80'hFFFFFFFFFFFFFFFFFFFF; // Corrigido para não-bloqueante (<=)
      end else begin
        case (estado)

          reset: begin
            digitos_value <= 80'hFFFFFFFFFFFFFFFFFFFF; // Substituído '{default} para agradar o Icarus
            ta            <= 0;
            col_lida      <= 4'b1111;
            td            <= 0;
            estado        <= leitura;
          end
          
          leitura: begin
            ta <= ta + 1;
            if (c0) begin
              col_lida <= col_matriz;
              td       <= 2;
              estado   <= db;
            end
            else if (ta >= 5000 && digitos_value.digits[0] != 4'hF) begin
                estado        <= arrayComE_up;
                digitos_value <= 80'hEEEEEEEEEEEEEEEEEEEE;
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
            else if(td >= 100) begin
                estado <= decodificar;
            end
          end
          
          decodificar: begin
            td <= 0;
            ta <= 0;
            // Modificado para usar a concatenação equivalente aos seus chutes corretos de E7 e ED
            if ({lin_matriz, col_matriz} == 8'b11100111) begin
                estado <= arrayValido;
            end
            else if({lin_matriz, col_matriz} == 8'b11101101) begin
                estado        <= arrayComB_up; 
                digitos_value <= 80'hBBBBBBBBBBBBBBBBBBBB;
            end
            else begin
                estado <= inserirNoArray;
                digitos_value.digits[19] <= digitos_value.digits[18];
                digitos_value.digits[18] <= digitos_value.digits[17];
                digitos_value.digits[17] <= digitos_value.digits[16];
                digitos_value.digits[16] <= digitos_value.digits[15];
                digitos_value.digits[15] <= digitos_value.digits[14];
                digitos_value.digits[14] <= digitos_value.digits[13];
                digitos_value.digits[13] <= digitos_value.digits[12];
                digitos_value.digits[12] <= digitos_value.digits[11];
                digitos_value.digits[11] <= digitos_value.digits[10];
                digitos_value.digits[10] <= digitos_value.digits[9];
                digitos_value.digits[9]  <= digitos_value.digits[8];
                digitos_value.digits[8]  <= digitos_value.digits[7];
                digitos_value.digits[7]  <= digitos_value.digits[6];
                digitos_value.digits[6]  <= digitos_value.digits[5];
                digitos_value.digits[5]  <= digitos_value.digits[4];
                digitos_value.digits[4]  <= digitos_value.digits[3];
                digitos_value.digits[3]  <= digitos_value.digits[2];
                digitos_value.digits[2]  <= digitos_value.digits[1];
                digitos_value.digits[1]  <= digitos_value.digits[0];
                digitos_value.digits[0]  <= tecla_lida;
            end
          end
          
          arrayValido: begin
            td            <= 0;
            estado        <= limparArray;
            digitos_value <= 80'hFFFFFFFFFFFFFFFFFFFF;
          end
          
          arrayComB_up: begin
            td            <= 0;
            estado        <= arrayComB_down;
            digitos_value <= 80'hBBBBBBBBBBBBBBBBBBBB;
          end
          
          arrayComB_down: begin
            td            <= 0;
            estado        <= limparArray;
            digitos_value <= 80'hFFFFFFFFFFFFFFFFFFFF;
          end
          
          arrayComE_up: begin
            td            <= 0;
            ta            <= 0;
            estado        <= arrayComE_down;
            digitos_value <= 80'hEEEEEEEEEEEEEEEEEEEE;
          end
          
          arrayComE_down: begin
            td            <= 0;
            estado        <= limparArray;
            digitos_value <= 80'hFFFFFFFFFFFFFFFFFFFF;
          end
          
          limparArray: begin
            if(c1) begin
                ta     <= 0;
                estado <= leitura;
            end
          end
          
          inserirNoArray: begin
            if (c1) begin
                ta     <= 0;
                estado <= leitura;
            end
          end
          
          tecladoDesativado: begin
            if(enable) begin
                estado <= leitura;
            end
          end
          
          default: begin
            td         <= 0;
            ta         <= 0;
            estado     <= reset;
            lin_matriz <= 4'b0111;
          end
        endcase
      end
  end

  // Bloco de validação de sinal ajustado de forma limpa para o Icarus
  always_ff @(posedge clk or posedge rst) begin
      if (rst) begin
          digitos_valid <= 0;
      end else begin
          if ((estado == arrayComB_up) || (estado == arrayComE_up) || (estado == arrayValido)) begin
             digitos_valid <= 1;
          end else begin
             digitos_valid <= 0;
          end
      end
  end

  // Bloco Combinacional Decodificador puro
  always_comb begin
      case (estado)
        decodificar: begin
          case (barramento_composto)
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
  
endmodule