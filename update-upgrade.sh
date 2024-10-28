#!/bin/bash

# Definición de colores
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[0;31m'
RESET='\033[0m'

while true; do
    echo -e "${YELLOW}¿Actualizar repositorios a la última versión? (s/n): ${RESET}"
    read answer
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]') # Convertir a minúsculas

    if [[ "$answer" == "s" ]]; then 
        echo -e "${YELLOW}Actualizando repositorios, espere...${RESET}"
        if sudo apt update -y; then
            echo -e "${GREEN}Repositorios actualizados correctamente.${RESET}"
        else
            echo -e "${RED}Error al actualizar los repositorios.${RESET}"
            break  # Salir si hay un error
        fi

        while true; do 
            echo -e "${YELLOW}¿Deseas también hacer un upgrade de los paquetes? (s/n): ${RESET}"
            read answerUpgrade
            answerUpgrade=$(echo "$answerUpgrade" | tr '[:upper:]' '[:lower:]')

            if [[ "$answerUpgrade" == "s" ]]; then 
                echo -e "${YELLOW}Actualizando paquetes, espere...${RESET}"
                if sudo apt upgrade -y; then
                    echo -e "${GREEN}Paquetes actualizados correctamente.${RESET}"
                else
                    echo -e "${RED}Error al actualizar los paquetes.${RESET}"
                fi
                break  # Rompemos el bucle después de hacer upgrade

            elif [[ "$answerUpgrade" == "n" ]]; then
                echo -e "${GREEN}Omitiendo el upgrade de los paquetes.${RESET}"
                sleep 1
                echo -e "${GREEN}Continuando con la instalación...${RESET}"
                break  # Rompemos el bucle de actualización

            else 
                echo -e "${RED}Entrada no válida. Por favor responde con 's' para sí o 'n' para no.${RESET}"
            fi
        done

        break  # Salimos del bucle principal después de actualizar

    elif [[ "$answer" == "n" ]]; then
        echo -e "${GREEN}Omitiendo la actualización de los repositorios.${RESET}"
        sleep 1
        echo -e "${GREEN}Continuando con la instalación...${RESET}"
        break  # Salimos del bucle principal

    else 
        echo -e "${RED}Entrada no válida. Por favor responde con 's' para sí o 'n' para no.${RESET}"
    fi
done