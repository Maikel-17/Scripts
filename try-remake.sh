#!/bin/bash

# Definiciones de colores (omitiendo por brevedad)
RESET='\033[0m'
YELLOW='\033[1;33m'
GREEN='\033[1;32m'
RED='\033[1;31m'
CYAN='\033[1;36m'

# ------------------ Preguntar si el servidor y cliente están en la misma red ------------------
while true; do
    echo -e "${YELLOW}¿El servidor y el cliente están en la misma red? (s/n): ${RESET}"  
    read respuesta
    respuesta=$(echo "$respuesta" | tr '[:upper:]' '[:lower:]')  # Convertir a minúsculas

    if [[ "$respuesta" == "s" ]]; then
        echo -e "${GREEN}Continuando con la configuración...${RESET}"
        break  # Salir del bucle

    elif [[ "$respuesta" == "n" ]]; then
        echo -e "${YELLOW}Por favor asegúrate de que el servidor y el cliente estén en la misma red antes de continuar.${RESET}"
        exit 1  # Salir del script con un código de error

    else
        echo -e "${RED}Por favor responde con 's' para sí o 'n' para no.${RESET}"  # Manejo de entrada no válida
    fi
done

echo

# ------------------ Solicitar IP o nombre del servidor LDAP ------------------
while true; do
    echo -e "${YELLOW}Por favor introduce la IP o nombre del host del servidor:${RESET} "
    read serverDomain

    if [[ "$serverDomain" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        break  # Entrada válida
    else
        echo -e "${RED}Formato inválido. Debe ser una IP o un nombre de host válido.${RESET}"
    fi
done

echo

# ------------------ Solicitar el nombre del servidor (primer 'dc=') ------------------
while true; do
    echo -e "${YELLOW}Por favor introduce el nombre del servidor (Ejemplo: 'example' para dc=example):${RESET}"
    read serverName

    if [[ "$serverName" =~ ^[a-zA-Z0-9]+$ ]]; then
        break  # Entrada válida
    else
        echo -e "${RED}Nombre de servidor inválido. Solo puedes usar letras y números.${RESET}"
    fi
done

echo

# ------------------ Solicitar la extensión del dominio (segundo 'dc=') ------------------
while true; do
    echo -e "${YELLOW}Por favor introduce la extensión del dominio (Ejemplo: 'com', 'org', 'net'):${RESET}"
    read extServ

    if [[ "$extServ" =~ ^[a-zA-Z]{2,}$ ]]; then
        break  # Entrada válida
    else
        echo -e "${RED}Extensión inválida. Solo se permiten letras y debe tener al menos 2 caracteres.${RESET}"
    fi
done

echo

# ------------------ Solicitar el CN del administrador de LDAP ------------------
while true; do
    echo -e "${YELLOW}Por favor introduce el nombre del administrador LDAP (Ejemplo: 'admin' para cn=admin):${RESET}"
    read adminName

    if [[ "$adminName" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        break  # Entrada válida
    else
        echo -e "${RED}Nombre de administrador inválido. Solo puedes usar letras, números, puntos (.), guiones bajos (_) y guiones (-).${RESET}"
    fi
done

echo

# ------------------ Solicitar contraseña del administrador de LDAP ------------------
while true; do
    echo -e "${YELLOW}Por favor proporcione una contraseña para el usuario administrador de LDAP: ${RESET}"
    read -s PassLDAP  # Leer la contraseña sin mostrarla
    echo  # Nueva línea

    if [[ -z "$PassLDAP" ]]; then
        echo -e "${RED}La contraseña no puede estar vacía. Inténtalo de nuevo.${RESET}"
    else
        echo -e "${GREEN}Contraseña aceptada.${RESET}"
        break  # Contraseña válida, salir del bucle
    fi
done

echo

# ------------------ BLOQUE DE CONTROL PARA VERIFICAR INFORMACIÓN INTRODUCIDA ------------------------
echo -e "${CYAN}Información introducida por el usuario:${RESET}"
echo "URI Dirección del servidor LDAP: $serverDomain"
echo "BASE BASE del servidor LDAP: $serverName"
echo "Extensión del dominio: $extServ"
echo "Nombre de administrador: $adminName"

sleep 2

# ------------------ Confirmación de la información introducida ------------------------
while true; do
    echo -e "${YELLOW}¿Es esta información correcta? (s/n): ${RESET}"
    read infoAnswer

    if [[ "$infoAnswer" =~ ^[Ss]$ ]]; then
        echo -e "${GREEN}Continuando con la instalación...${RESET}"
        break  # Salir del bucle

    elif [[ "$infoAnswer" =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Por favor, introduce nuevamente los campos que deseas corregir.${RESET}"
        # Aquí se pueden añadir los bucles para pedir nuevamente la información que el usuario desea corregir
        while true; do
            echo -e "${YELLOW}¿Qué campo deseas corregir? (1: Servidor, 2: Nombre, 3: Extensión, 4: Administrador, 5: Contraseña): ${RESET}"
            read fieldChoice

            case "$fieldChoice" in
                1)
                    while true; do
                        echo -e "${YELLOW}Por favor introduce la IP o nombre del host del servidor:${RESET} "
                        read serverDomain
                        if [[ "$serverDomain" =~ ^[a-zA-Z0-9.-]+$ ]]; then
                            break  # Entrada válida
                        else
                            echo -e "${RED}Formato inválido. Debe ser una IP o un nombre de host válido.${RESET}"
                        fi
                    done
                    ;;
                2)
                    while true; do
                        echo -e "${YELLOW}Por favor introduce el nombre del servidor (Ejemplo: 'example' para dc=example):${RESET}"
                        read serverName
                        if [[ "$serverName" =~ ^[a-zA-Z0-9]+$ ]]; then
                            break  # Entrada válida
                        else
                            echo -e "${RED}Nombre de servidor inválido. Solo puedes usar letras y números.${RESET}"
                        fi
                    done
                    ;;
                3)
                    while true; do
                        echo -e "${YELLOW}Por favor introduce la extensión del dominio (Ejemplo: 'com', 'org', 'net'):${RESET}"
                        read extServ
                        if [[ "$extServ" =~ ^[a-zA-Z]{2,}$ ]]; then
                            break  # Entrada válida
                        else
                            echo -e "${RED}Extensión inválida. Solo se permiten letras y debe tener al menos 2 caracteres.${RESET}"
                        fi
                    done
                    ;;
                4)
                    while true; do
                        echo -e "${YELLOW}Por favor introduce el nombre del administrador LDAP (Ejemplo: 'admin' para cn=admin):${RESET}"
                        read adminName
                        if [[ "$adminName" =~ ^[a-zA-Z0-9._-]+$ ]]; then
                            break  # Entrada válida
                        else
                            echo -e "${RED}Nombre de administrador inválido. Solo puedes usar letras, números, puntos (.), guiones bajos (_) y guiones (-).${RESET}"
                        fi
                    done
                    ;;
                5)
                    while true; do
                        echo -e "${YELLOW}Por favor proporcione una contraseña para el usuario administrador de LDAP: ${RESET}"
                        read -s PassLDAP  # Leer la contraseña sin mostrarla
                        echo  # Nueva línea
                        if [[ -z "$PassLDAP" ]]; then
                            echo -e "${RED}La contraseña no puede estar vacía. Inténtalo de nuevo.${RESET}"
                        else
                            echo -e "${GREEN}Contraseña aceptada.${RESET}"
                            break  # Contraseña válida, salir del bucle
                        fi
                    done
                    ;;
                *)
                    echo -e "${RED}Opción no válida. Por favor elige un número entre 1 y 5.${RESET}"
                    ;;
            esac
            
            echo -e "${CYAN}Información introducida por el usuario:${RESET}"
            echo "URI Dirección del servidor LDAP: $serverDomain"
            echo "BASE BASE del servidor LDAP: $serverName"
            echo "Extensión del dominio: $extServ"
            echo "Nombre de administrador: $adminName"
            echo -e "${YELLOW}¿Es esta información correcta? (s/n): ${RESET}"
            read infoAnswer
            
            if [[ "$infoAnswer" =~ ^[Ss]$ ]]; then
                echo -e "${GREEN}Continuando con la instalación...${RESET}"
                break  # Salir del bucle de corrección
            fi
        done
        break  # Salir del bucle principal
    else
        echo -e "${RED}Opción no válida. El script se cerrará.${RESET}"
        exit 1
    fi
done