#!/bin/bash

# Cores para a interface
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; WHITE='\033[1;37m'; NC='\033[0m'

BOTS_FILE="/data/data/com.termux/files/home/.bot_manager_bots.conf"
LOG_DIR="/data/data/com.termux/files/home/bot_logs"

mkdir -p "$LOG_DIR"

# Função para exibir animação de carregamento
loading_animation() {
    local duration=$1
    local message=$2
    local pid=$!
    local i=0
    local chars=("-" "\\" "|" "/")
    echo -ne "${CYAN}${message} ${NC}"
    while kill -0 $pid 2>/dev/null; do
        echo -ne "\r${CYAN}${message} ${chars[i++ % ${#chars[@]}]} ${NC}"
        sleep 0.1
    done
    echo -ne "\r${CYAN}${message} ${GREEN}[OK]${NC}\n"
}

# Função para exibir barra de progresso (adaptada, pode não ser usada diretamente aqui)
progress_bar() {
    local duration=$1
    local message=$2
    local progress=0
    local bar_length=20
    echo -ne "${CYAN}${message} [${NC}"
    for ((i=0; i<bar_length; i++)); do
        echo -ne "${GREEN}#${NC}"
        sleep $(echo "scale=2; $duration / $bar_length" | bc)
    done
    echo -e "${CYAN}] ${GREEN}100%${NC}"
}

# Função para adicionar um novo bot
add_bot() {
    clear
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${WHITE}  ADICIONAR NOVO BOT${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    echo -ne "${WHITE}Nome do Bot (ex: TelegramBot): ${NC}"; read -r bot_name
    echo -ne "${WHITE}Comando para iniciar o Bot (ex: python bot.py): ${NC}"; read -r bot_command

    if [ -z "$bot_name" ] || [ -z "$bot_command" ]; then
        echo -e "${RED}Nome e comando do bot não podem ser vazios!${NC}"
    else
        echo "$bot_name;$bot_command;" >> "$BOTS_FILE"
        echo -e "${GREEN}Bot '$bot_name' adicionado com sucesso!${NC}"
    fi
    echo -e "\n${BLUE}Pressione ENTER para continuar...${NC}"; read -r
}

# Função para listar bots
list_bots() {
    clear
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${WHITE}  LISTA DE BOTS CADASTRADOS${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    if [ ! -f "$BOTS_FILE" ] || [ ! -s "$BOTS_FILE" ]; then
        echo -e "${YELLOW}Nenhum bot cadastrado ainda.${NC}"
    else
        echo -e "${WHITE}ID | Nome do Bot      | Status   | PID      | Comando${NC}"
        echo -e "${BLUE}-----------------------------------------------------${NC}"
        local id=1
        while IFS=';' read -r name command pid;
        do
            local status="${RED}PARADO${NC}"
            local current_pid="N/A"
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                status="${GREEN}RODANDO${NC}"
                current_pid="$pid"
            fi
            printf "${WHITE}%-2s | %-17s | %-10s | %-8s | %s${NC}\n" "$id" "$name" "$status" "$current_pid" "$command"
            id=$((id+1))
        done < "$BOTS_FILE"
    fi
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "\n${BLUE}Pressione ENTER para continuar...${NC}"; read -r
}

# Função para iniciar um bot
start_bot() {
    clear
    list_bots_selection
    if [ ! -f "$BOTS_FILE" ] || [ ! -s "$BOTS_FILE" ]; then
        echo -e "${RED}Nenhum bot para iniciar.${NC}"
        echo -e "\n${BLUE}Pressione ENTER para continuar...${NC}"; read -r
        return
    fi
    echo -ne "${WHITE}Digite o ID do bot para iniciar: ${NC}"; read -r bot_id

    local line=$(sed -n "${bot_id}p" "$BOTS_FILE")
    if [ -z "$line" ]; then
        echo -e "${RED}ID de bot inválido!${NC}"
    else
        IFS=';' read -r name command current_pid <<< "$line"
        if [ -n "$current_pid" ] && kill -0 "$current_pid" 2>/dev/null; then
            echo -e "${YELLOW}Bot '$name' já está rodando com PID $current_pid.${NC}"
        else
            echo -e "${CYAN}Iniciando bot '$name'...
""
            nohup $command > "$LOG_DIR/${name}.log" 2>&1 & 
            local new_pid=$!
            sed -i "${bot_id}s/;[^;]*$/;$new_pid/" "$BOTS_FILE"
            echo -e "${GREEN}Bot '$name' iniciado com PID $new_pid. Log em '$LOG_DIR/${name}.log'${NC}"
        fi
    fi
    echo -e "\n${BLUE}Pressione ENTER para continuar...${NC}"; read -r
}

# Função para parar um bot
stop_bot() {
    clear
    list_bots_selection
    if [ ! -f "$BOTS_FILE" ] || [ ! -s "$BOTS_FILE" ]; then
        echo -e "${RED}Nenhum bot para parar.${NC}"
        echo -e "\n${BLUE}Pressione ENTER para continuar...${NC}"; read -r
        return
    fi
    echo -ne "${WHITE}Digite o ID do bot para parar: ${NC}"; read -r bot_id

    local line=$(sed -n "${bot_id}p" "$BOTS_FILE")
    if [ -z "$line" ]; then
        echo -e "${RED}ID de bot inválido!${NC}"
    else
        IFS=';' read -r name command pid <<< "$line"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo -e "${CYAN}Parando bot '$name' (PID: $pid)...${NC}"
            kill "$pid"
            sed -i "${bot_id}s/;[^;]*$/;/" "$BOTS_FILE"
            echo -e "${GREEN}Bot '$name' parado com sucesso!${NC}"
        else
            echo -e "${YELLOW}Bot '$name' não está rodando ou PID inválido.${NC}"
        fi
    fi
    echo -e "\n${BLUE}Pressione ENTER para continuar...${NC}"; read -r
}

# Função para reiniciar um bot
restart_bot() {
    clear
    list_bots_selection
    if [ ! -f "$BOTS_FILE" ] || [ ! -s "$BOTS_FILE" ]; then
        echo -e "${RED}Nenhum bot para reiniciar.${NC}"
        echo -e "\n${BLUE}Pressione ENTER para continuar...${NC}"; read -r
        return
    fi
    echo -ne "${WHITE}Digite o ID do bot para reiniciar: ${NC}"; read -r bot_id

    local line=$(sed -n "${bot_id}p" "$BOTS_FILE")
    if [ -z "$line" ]; then
        echo -e "${RED}ID de bot inválido!${NC}"
    else
        IFS=';' read -r name command pid <<< "$line"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo -e "${CYAN}Parando bot '$name' (PID: $pid)...${NC}"
            kill "$pid"
            sed -i "${bot_id}s/;[^;]*$/;/" "$BOTS_FILE"
            sleep 2 # Dá um tempo para o processo morrer
        else
            echo -e "${YELLOW}Bot '$name' não estava rodando, apenas iniciando.${NC}"
        fi
        echo -e "${CYAN}Iniciando bot '$name'...
""
        nohup $command > "$LOG_DIR/${name}.log" 2>&1 & 
        local new_pid=$!
        sed -i "${bot_id}s/;[^;]*$/;$new_pid/" "$BOTS_FILE"
        echo -e "${GREEN}Bot '$name' reiniciado com PID $new_pid. Log em '$LOG_DIR/${name}.log'${NC}"
    fi
    echo -e "\n${BLUE}Pressione ENTER para continuar...${NC}"; read -r
}

# Função auxiliar para listar bots sem pausa para seleção
list_bots_selection() {
    echo -e "${BLUE}=====================================================${NC}"
    echo -e "${WHITE}  LISTA DE BOTS CADASTRADOS${NC}"
    echo -e "${BLUE}=====================================================${NC}"
    if [ ! -f "$BOTS_FILE" ] || [ ! -s "$BOTS_FILE" ]; then
        echo -e "${YELLOW}Nenhum bot cadastrado ainda.${NC}"
    else
        echo -e "${WHITE}ID | Nome do Bot      | Status   | PID      | Comando${NC}"
        echo -e "${BLUE}-----------------------------------------------------${NC}"
        local id=1
        while IFS=';' read -r name command pid;
        do
            local status="${RED}PARADO${NC}"
            local current_pid="N/A"
            if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
                status="${GREEN}RODANDO${NC}"
                current_pid="$pid"
            fi
            printf "${WHITE}%-2s | %-17s | %-10s | %-8s | %s${NC}\n" "$id" "$name" "$status" "$current_pid" "$command"
            id=$((id+1))
        done < "$BOTS_FILE"
    fi
    echo -e "${BLUE}=====================================================${NC}"
}

# Menu principal
main_menu() {
    while true; do
        clear
        echo -e "${GREEN}"
        echo "  ██████╗ ██╗██████╗  ██████╗ ███╗   ███╗ ██████╗ ██████╗ ███████╗"
        echo "  ██╔══██╗██║██╔══██╗██╔═══██╗████╗ ████║██╔═══██╗██╔══██╗╚══███╔╝"
        echo "  ██║  ██║██║██║  ██║██║   ██║██╔████╔██║██║   ██║██║  ██║  ███╔╝ "
        echo "  ██║  ██║██║██║  ██║██║   ██║██║╚██╔╝██║██║   ██║██║  ██║ ███╔╝  "
        echo "  ██████╔╝██║██████╔╝╚██████╔╝██║ ╚═╝ ██║╚██████╔╝██████╔╝███████╗"
        echo "  ╚═════╝ ╚═╝╚═════╝  ╚═════╝ ╚═╝     ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝"
        echo -e "                     ${WHITE}>>> DIDOMODZ - BOT MANAGER <<<${NC}"
        echo -e "${BLUE}=====================================================${NC}"
        echo -e "${WHITE}  1) ${GREEN}Adicionar Novo Bot${NC}"
        echo -e "${WHITE}  2) ${CYAN}Listar Bots${NC}"
        echo -e "${WHITE}  3) ${GREEN}Iniciar Bot${NC}"
        echo -e "${WHITE}  4) ${RED}Parar Bot${NC}"
        echo -e "${WHITE}  5) ${YELLOW}Reiniciar Bot${NC}"
        echo -e "${WHITE}  6) ${MAGENTA}Monitorar Bots (Listar com Status)${NC}"
        echo -e "${WHITE}  7) ${WHITE}Sair${NC}"
        echo -e "${BLUE}=====================================================${NC}"
        echo -ne "${WHITE}Escolha sua opção > ${NC}"; read -r opcao

        case $opcao in
            1) add_bot ;;
            2) list_bots ;;
            3) start_bot ;;
            4) stop_bot ;;
            5) restart_bot ;;
            6) list_bots ;;
            7) exit 0 ;;
            *) echo -e "${RED}Opção inválida!${NC}"; echo -e "\n${BLUE}Pressione ENTER para continuar...${NC}"; read -r ;;
        esac
    done
}

# Inicia o menu principal
main_menu
