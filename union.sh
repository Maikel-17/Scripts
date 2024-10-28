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

# -------------------------- Cabecera LDAPUnion ------------------------------

echo "██╗     ██████╗  █████╗ ██████╗       ██╗   ██╗███╗   ██╗██╗ ██████╗ ███╗   ██╗"
echo "██║     ██╔══██╗██╔══██╗██╔══██╗      ██║   ██║████╗  ██║██║██╔═══██╗████╗  ██║"
echo "██║     ██║  ██║███████║██████╔╝█████╗██║   ██║██╔██╗ ██║██║██║   ██║██╔██╗ ██║"
echo "██║     ██║  ██║██╔══██║██╔═══╝ ╚════╝██║   ██║██║╚██╗██║██║██║   ██║██║╚██╗██║"
echo "███████╗██████╔╝██║  ██║██║           ╚██████╔╝██║ ╚████║██║╚██████╔╝██║ ╚████║"
echo "╚══════╝╚═════╝ ╚═╝  ╚═╝╚═╝            ╚═════╝ ╚═╝  ╚═══╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝"

echo -e "${YELLOW}								Script made by: Mike17 ${RESET}"

echo 

# ------------------ Check previo para ejecutar script como root ----------------
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script debe ejecutarse como root${RESET}"
   exit 1
fi


# ------------------ Actualizar y mejorar repositorios ---------------------------

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
while [[ ! "$serverDomain" =~ ^[a-zA-Z0-9.-]+$ ]]; do
    echo -e "${YELLOW}Por favor introduce la IP o nombre del host del servidor${RESET}: "
    read serverDomain

    if [[ ! "$serverDomain" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        echo -e "${RED}Formato inválido. Debe ser una IP o un nombre de host válido.${RESET}"
        serverDomain=""  # Limpiar la variable si no es válida
    fi
done

# ------------------ Solicitar el DN del servidor ------------------

# Solicitar el nombre del servidor (primer 'dc=')
while [[ ! "$serverName" =~ ^[a-zA-Z0-9]+$ ]]; do
    echo -e "${YELLOW}Por favor introduce el nombre del servidor (Ejemplo: 'example' para dc=example):${RESET}"
    read serverName

    if [[ ! "$serverName" =~ ^[a-zA-Z0-9]+$ ]]; then
        echo -e "${RED}Nombre de servidor inválido. Solo puedes usar letras y números.${RESET}"
        serverName=""
    fi
done

# Solicitar la extensión del dominio (segundo 'dc=')
while [[ ! "$extServ" =~ ^[a-zA-Z]{2,}$ ]]; do
    echo -e "${YELLOW}Por favor introduce la extensión del dominio (Ejemplo: 'com', 'org', 'net'):${RESET}"
    read extServ

    if [[ ! "$extServ" =~ ^[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}Extensión inválida. Solo se permiten letras y debe tener al menos 2 caracteres.${RESET}"
        extServ=""
    fi
done

echo

# ------------------ Solicitar el CN del administrador de LDAP ------------------

while [[ ! "$adminName" =~ ^[a-zA-Z0-9._-]+$ ]]; do
    echo -e "${YELLOW}Por favor introduce el nombre del administrador LDAP (Ejemplo: 'admin' para cn=admin):${RESET}"
    read adminName

    if [[ ! "$adminName" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        echo -e "${RED}Nombre de administrador inválido. Solo puedes usar letras, números, puntos (.), guiones bajos (_) y guiones (-).${RESET}"
        adminName=""
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

# ------------------ BLOQUE DE CONTROL PARA VERIFICAR INFORMACIÓN INTRODUCIDA ------------------------

echo -e "${CYAN}Información introducida por el usuario${RESET}"

echo "$URI Dirección del servidor LDAP"
echo "$BASE BASE del servidor LDAP"
echo "$CnServer ADMIN del servidor LDAP"
echo "$CnDnServer DN completo del servidor LDAP"

sleep 5

echo -e "${YELLOW}¿Es esta información correcta? (s/n): ${RESET}"
read infoAnswer

if [[ "$infoAnswer" =~ ^[Ss]$ ]]; then
    echo -e "${GREEN}Continuando con la instalación...${RESET}"
    
elif 
    [[ "$infoAnswer" =~ ^[Nn]$ ]]; then
    echo -e "Vuelva a iniciar el script."
    exit 1
fi



# ------------------ Variables de configuración LDAP ------------------

URI="ldap://$serverDomain" 			# URL del servidor
BASE="dc=$serverName,dc=$extServ"   # BASE del servidor
CnServer="cn=$adminName"       		# ADMIN del servidor
CnDnServer="$CnServer,$BASE"  		# Unión del CN y el DN
LDAPVersion=3						# Versión de LDAP
varlibconf="/etc/ldap/ldap.conf" 	# Ruta del archivo de configuración de LDAP
varlibconf2="/etc/ldap.conf"		# Ruta del archivo de configuración LDAP de libnss-ldap
filesldap="files ldap"				# Texto para sustituir en nsswitch.conf
nssconf="/etc/nsswitch.conf"		# Ruta del fichero nsswitch.conf

# Conf PAM
authpam="auth sufficient  pam_ldap.so" 								 # Línea de texto añadida a auth
accpam="account sufficient  pam_ldap.so" 							 # Línea de texto añadida a account
sspam="session required  pam_mkhomedir.so skel=/etc/skel umask=0077" # Línea de texto añadida a session
passpam="password sufficient pam_ldap.so" 							 # Línea de texto añadida a password

# ------------------ Actualización de repositorios e instalación de dependencias ------------------
echo -e "${YELLOW}Instalando librerias LDAP, espere por favor...${RESET}"

# Actualizar repositorios e instalar las librerías necesarias
sudo DEBIAN_FRONTEND=noninteractive apt install -y libnss-ldap libpam-ldap ldap-utils 

echo -e "${GREEN}Instalación completada.${RESET}"

# ------------------ Configuración del archivo /etc/ldap/ldap.conf ------------------

# Evitar duplicados en la configuración
if ! grep -q "^URI $URI" "$varlibconf"; then
	sudo sed -i '/^#URI/s/^#//;s|URI.*|URI  '"$URI"'|' "$varlibconf"
fi

if ! grep -q "^BASE $BASE" "$varlibconf"; then
	sudo sed -i '/^#BASE/s/^#//;s|dc=example,dc=com|'"$BASE"'|' "$varlibconf"
fi

if ! grep -q "^LDAP_VERSION" "$varlibconf"; then
	sudo sed -i '/^URI/a LDAP_VERSION 3' "$varlibconf"
fi

# ------------------ Configuración del archivo /etc/ldap.conf ------------------

# Modificar el archivo ldap.conf con los valores introducidos por el usuario
if grep -q "^URI" "$varlibconf2"; then
    sudo sed -i "s|^URI.*|URI $URI|" "$varlibconf2"
else
    echo "URI $URI" | sudo tee -a "$varlibconf2" > /dev/null
fi

if grep -q "^BASE" "$varlibconf2"; then
    sudo sed -i "s|^BASE.*|BASE $BASE|" "$varlibconf2"
else
    echo "BASE $BASE" | sudo tee -a "$varlibconf2" > /dev/null
fi

if grep -q "^ldap_version" "$varlibconf2"; then
    sudo sed -i "s|^ldap_version.*|ldap_version $LDAPVersion|" "$varlibconf2"
else
    echo "ldap_version $LDAPVersion" | sudo tee -a "$varlibconf2" > /dev/null
fi

echo -e "${GREEN}Archivo /etc/ldap.conf configurado correctamente.${RESET}"

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
sudo sed -i "s|^passwd:.*|passwd: $filesldap|" "$nssconf"
sudo sed -i "s|^group:.*|group: $filesldap|" "$nssconf"
sudo sed -i "s|^shadow:.*|shadow: $filesldap|" "$nssconf"

# Mostrar configuración final del archivo nsswitch.conf
echo -e "${CYAN}Resultado de la configuración de nsswitch.conf:${RESET}"
sudo cat $nssconf

echo

# ------------------ Verificación de la configuración ------------------
echo -e "${GREEN}Todo instalado y configurado correctamente.${RESET}"
echo "Conectando con DN: $CnDnServer"
echo
sleep 2
echo "Base de búsqueda: $BASE"
echo

# ------------------ Verificación de conexión LDAP ------------------
echo -e "${YELLOW}Verificando conexión al servidor LDAP...${RESET}"

ldapsearch -x -D "$CnDnServer" -W -b "$BASE"
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}Conexión LDAP exitosa.${RESET}"
else
    echo -e "${RED}Error en la conexión LDAP. Verifica la configuración.${RESET}"
    exit 1
fi

# Preguntar al cliente el uid de un usuario para verificar la configuración
echo -e "${CYAN}Para verificar la unión, introduzca el uid de un usuario: ${RESET}" 
sleep 1
read uiduserldap 
echo


# Obtener la información del usuario del servidor LDAP
sudo getent passwd "$uiduserldap"
echo

# -------------------------- INSTALACIÓN NSLCD ----------------------------------

read -p "¿Desea instalar nslcd para acceder a LDAP gráficamente? (s/n): " instNslcd
if [[ "$instNslcd" =~ ^[Ss]$ ]]; then
    # ------------------ Instalación de nslcd ------------------
    echo -e "${YELLOW}Instalando nslcd, espere por favor...${RESET}"

    # Actualizar repositorios e instalar nslcd
    sudo DEBIAN_FRONTEND=noninteractive apt install -y nslcd 

    echo -e "${GREEN}El servicio nslcd ha sido instalado correctamente.${RESET}"

    # ------------------ Configuración de /etc/nslcd.conf ------------------
    echo -e "${YELLOW}Configurando nslcd...${RESET}"

    nslcdconf="/etc/nslcd.conf"  # Ruta del archivo de configuración de nslcd

    # Crear o modificar el archivo de configuración nslcd.conf
    cat <<EOL | sudo tee "$nslcdconf"
# Configuración de nslcd
uri ldap://$serverDomain
base $BASE
binddn $CnDnServer
bindpw $PassLDAP
# Opciones de búsqueda
scope sub
# Configuración de caché (ajusta según tus necesidades)
# Uncomment to enable caching
# cache credential
# cache group
# cache passwd
# cache shadow
EOL

    echo -e "${GREEN}Archivo /etc/nslcd.conf configurado correctamente.${RESET}"

    # ------------------ Reiniciar el servicio nslcd ------------------
    echo -e "${YELLOW}Reiniciando el servicio nslcd...${RESET}"
    sudo systemctl restart nslcd

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}nslcd reiniciado correctamente.${RESET}"
    else
        echo -e "${RED}Error al reiniciar nslcd. Verifica la configuración.${RESET}"
        exit 1
    fi

    # Habilitar el servicio nslcd para que inicie al arrancar
    echo -e "${YELLOW}Habilitando el servicio nslcd para que inicie al arrancar...${RESET}"
    sudo systemctl enable nslcd
    echo -e "${GREEN}Servicio nslcd habilitado correctamente.${RESET}"
else
    echo -e "${YELLOW}Opción de instalación de nslcd omitida.${RESET}"
fi


# ----------------- Acceso a el sistema como usuario del servidor ------------------
echo -e "${CYAN}¿Acceder a el sistema como cliente LDAP? (Interfaz de comando) (s/n) ${RESET}: "
read comAccess

if [[ "$comAccess" =~ ^[Ss]$ ]]; then
    echo -e "${CYAN}Porfavor introduzca el UID de algún usuario del servidor: ${RESET}"
    read uiduserldap

    echo -e "${GREEN}Accediendo a el sistema como $uiduserldap... ${RESET}"
    sleep 2
    su - $uiduserldap

else 
    echo -e "${GREEN}Continuando con la instalación... ${RESET}"
fi


# ------------------ Fichero que almacena las variables para comprobación -----------------

sudo touch /var/tmp/varuser.txt # Creamos el archivo en temp

cat << EOL > "/var/tmp/varuser.txt" 

# Archivo que contiene las variables introducidas en la instalación
URI=$URI
BASE=$BASE
CnServer=$CnServer
encryptedPass=$(echo -n "$PassLDAP" | openssl dgst -sha256)
CnDnServer=$CnDnServer
EOL