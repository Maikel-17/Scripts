#!/bin/bash

# Nombre script: Union.sh
# Descripción: Script para la configuración y agregación de un cliente a un servidor OPEN LDAP
# Autor:
# Fecha creación: 14/10/24
# Fecha finalización: */10/24

# ------------------ Definición de colores para texto ------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

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

while [[ ! "$IPServerLDAP" =~ ^ldap://[a-zA-Z0-9.-]+$ ]]; do
    echo -e  "${YELLOW}Por favor introduce la IP o host del servidor en el formato ldap://<IP> o ldap://<Nombre del host>${RESET}: " 
    read IPServerLDAP 

    if [[ ! "$IPServerLDAP" =~ ^ldap://[a-zA-Z0-9.-]+$ ]]; then
        echo -e "${RED}Formato inválido. Debe ser 'ldap://<IP>' o 'ldap://<Nombre del host>'.${RESET}"
        IPServerLDAP=""  # Limpiar la variable si no es válida
    fi
done

echo

# ------------------ Solicitar el DN del servidor ------------------

while [[ ! "$serverBase" =~ ^dc=[a-zA-Z0-9]+,dc=[a-zA-Z0-9]{2,}$ ]]; do
    echo -e "${YELLOW}Por favor introduce el Distinguished Name de tu servidor (Formato: dc=servidor,dc=extension)${RESET}: "
    read serverBase  

    if [[ ! "$serverBase" =~ ^dc=[a-zA-Z0-9]+,dc=[a-zA-Z0-9]{2,}$ ]]; then
        echo -e "${RED}Formato de DN inválido. Debe ser 'dc=servidor,dc=extension'.${RESET}"
        serverBase=""
    fi
done

echo

# ------------------ Solicitar el CN del administrador de LDAP ------------------

while [[ ! "$CnServer" =~ ^cn=[a-zA-Z0-9._-]+$ ]]; do
    echo -e "${YELLOW}Por favor introduce el usuario administrador de LDAP (Formato: cn=usuario)${RESET}: "  
    read CnServer

    if [[ ! "$CnServer" =~ ^cn=[a-zA-Z0-9._-]+$ ]]; then
        echo -e "${RED}Formato de CN inválido. Debe ser 'cn=usuario'.${RESET}"
        CnServer=""
    fi
done

echo

# ------------------ Solicitar contraseña del administrador de LDAP ------------------

while true; do
    echo -e "${YELLOW}Por favor proporcione una contraseña para el usuario administrador de LDAP: ${RESET}" 
    read PassLDAP
    echo  # Nueva línea

    if [[ -z "$PassLDAP" ]]; then
        echo -e "${RED}La contraseña no puede estar vacía. Inténtalo de nuevo.${RESET}"
    else
        echo -e "${GREEN}Contraseña aceptada.${RESET}"
        break  # Contraseña válida, salir del bucle
    fi
done

echo

# ------------------ Variables de configuración LDAP ------------------
dnServer="$CnServer,$serverBase"  # Unión del CN y el DN
LDAPVersion="3"                  # Versión del protocolo LDAP
LDAPassHsh="md5"                 # Hash para la encriptación de la contraseña
varlibconf="/etc/ldap/ldap.conf"  # Ruta del archivo de configuración de LDAP

# ------------------ Configuración de nsswitch.conf ------------------
compatldap="compat ldap"
nssconf="/etc/nsswitch.conf"

# ------------------ Configuración de archivos PAM (libpam-ldap) ------------------
authpam="auth sufficient  pam_ldap.so"
accpam="account sufficient  pam_ldap.so"
sspam="session required  pam_mkhomedir.so skel=/etc/skel umask=0077"
passpam="password sufficient pam_ldap.so"

# ------------------ Preconfiguración de las librerías con debconf ------------------
echo  "libnss-ldap libnss-ldap/ldap-server string $IPServerLDAP" | sudo debconf-set-selections
echo  "libnss-ldap libnss-ldap/base-dn string $serverBase" | sudo debconf-set-selections
echo  "libnss-ldap libnss-ldap/binddn string $dnServer" | sudo debconf-set-selections
echo  "libnss-ldap libnss-ldap/bindpw password $PassLDAP" | sudo debconf-set-selections
echo  "libnss-ldap libnss-ldap/rootbinddn string $dnServer" | sudo debconf-set-selections
echo  "libnss-ldap libnss-ldap/ldap_version select $LDAPVersion" | sudo debconf-set-selections

echo
# ------------------ Preconfiguración de libpam-ldap ------------------
echo "libpam-ldap libpam-ldap/ldap-server string $IPServerLDAP" | sudo debconf-set-selections
echo "libpam-ldap libpam-ldap/base-dn string $serverBase" | sudo debconf-set-selections
echo "libpam-ldap libpam-ldap/binddn string $dnServer" | sudo debconf-set-selections
echo "libpam-ldap libpam-ldap/bindpw password $PassLDAP" | sudo debconf-set-selections
echo "libpam-ldap libpam-ldap/rootbinddn string $dnServer" | sudo debconf-set-selections
echo "libpam-ldap libpam-ldap/ldap_version select $LDAPVersion" | sudo debconf-set-selections

echo

# ------------------ Preconfiguración de ldap-utils ------------------
echo "ldap-utils ldap-utils/ldap-server string $IPServerLDAP" | sudo debconf-set-selections
echo "ldap-utils ldap-utils/ldap-base string $serverBase" | sudo debconf-set-selections

echo

# ------------------ Actualización de repositorios e instalación de dependencias ------------------
echo -e "${YELLOW}Actualizando repositorios y dependencias, espere por favor...${RESET}"

# Actualizar repositorios e instalar las librerías necesarias
sudo apt update > /dev/null && sudo apt upgrade > /dev/null
sudo DEBIAN_FRONTEND=noninteractive apt install -y libnss-ldap libpam-ldap ldap-utils  > /dev/null

echo -e "${GREEN}Instalación completada.${RESET}"

# ------------------ Configuración del archivo ldap.conf ------------------
# Evitar duplicados en la configuración
if ! grep -q "^BASE $serverBase" "$varlibconf"; then
    sudo sed -i '/^#BASE/s/^#//;s|dc=example,dc=com|'"$serverBase"'|' "$varlibconf"
fi 

if ! grep -q "^URI $IPServerLDAP" "$varlibconf"; then
    sudo sed -i '/^#URI/s/^#//;s|URI.*|URI  '"$IPServerLDAP"'|' "$varlibconf"
fi 

if ! grep -q "^LDAP_VERSION" "$varlibconf"; then
    sudo sed -i '/^URI/a LDAP_VERSION 3' "$varlibconf"
fi

# ------------------ Configuración de archivos PAM ------------------
# Evitar duplicados en los archivos PAM

# auth
if ! grep -q "^$authpam" "/etc/pam.d/common-auth"; then
    echo "$authpam" | sudo tee -a /etc/pam.d/common-auth > /dev/null
fi

# account
if ! grep -q "^$accpam" "/etc/pam.d/common-account"; then
    echo "$accpam" | sudo tee -a /etc/pam.d/common-account > /dev/null
fi

# password
if ! grep -q "^$passpam" "/etc/pam.d/common-password"; then
    echo "$passpam" | sudo tee -a /etc/pam.d/common-password > /dev/null
fi

# session
if ! grep -q "^$sspam" "/etc/pam.d/common-session"; then
    echo "$sspam" | sudo tee -a /etc/pam.d/common-session > /dev/null
fi

# ------------------ Configuración de nsswitch.conf ------------------
sudo sed -i "s|^passwd:.*|passwd: $compatldap|" "$nssconf"
sudo sed -i "s|^group:.*|group: $compatldap|" "$nssconf"
sudo sed -i "s|^shadow:.*|shadow: $compatldap|" "$nssconf"

# Mostrar configuración final del archivo nsswitch.conf
echo -e "${CYAN}Resultado de la configuración de nsswitch.conf:${RESET}"
sudo cat $nssconf

echo

# ------------------ Verificación de la configuración ------------------
echo -e "${GREEN}Todo instalado y configurado correctamente.${RESET}"
echo "Conectando con DN: $dnServer"
echo "Base de búsqueda: $serverBase"

# Comprobar conexión con el servidor LDAP
ldapsearch -x -D "$dnServer" -W -b "$serverBase"

# Preguntar al cliente el uid de un usuario para verificar la configuración
# read -e -p "${GREEN}Para verificar la unión, introduzca el uid de un usuario: ${RESET}" uidserver

# Obtener la información del usuario del servidor LDAP
# sudo getent passwd "$uidserver"