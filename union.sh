#!/bin/bash

# Nombre script: Union.sh
# Descripción: Script para la configuración y agregación de un cliente a un servidor OPEN LDAP
# Autor: Miguel Hernández Andreu 
# Fecha creación: 14/10/24
# Fecha finalización: 18/10/24

# ------------------ Definición de colores para texto ------------------
BLACK='\033[1;30m'
RED='\033[1;31m'
GREEN='\033[1;32m'
BLUE='\033[1;34m'
MAGENTA='\033[1;35m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

# -------------------------- Cabecera LDAPUnion ------------------------------
echo "                                                                               "
echo "                                                                               "
echo "██╗     ██████╗  █████╗ ██████╗       ██╗   ██╗███╗   ██╗██╗ ██████╗ ███╗   ██╗"
echo "██║     ██╔══██╗██╔══██╗██╔══██╗      ██║   ██║████╗  ██║██║██╔═══██╗████╗  ██║"
echo "██║     ██║  ██║███████║██████╔╝█████╗██║   ██║██╔██╗ ██║██║██║   ██║██╔██╗ ██║"
echo "██║     ██║  ██║██╔══██║██╔═══╝ ╚════╝██║   ██║██║╚██╗██║██║██║   ██║██║╚██╗██║"
echo "███████╗██████╔╝██║  ██║██║           ╚██████╔╝██║ ╚████║██║╚██████╔╝██║ ╚████║"
echo "╚══════╝╚═════╝ ╚═╝  ╚═╝╚═╝            ╚═════╝ ╚═╝  ╚═══╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝"

echo -e "${CYAN}								Developed by: Miguel Hernández ${RESET}"

echo 

# ------------------ Check previo para ejecutar script como root -----------------

# Si el usuario que está ejecutando el script no es root sale del script 
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script debe ejecutarse como root${RESET}"
   exit 1
fi

# ------------------ Actualizar repositorios ---------------------------
echo -e "${CYAN}Actualizando repositorios...${RESET}"
sudo apt update -y 
sleep 2	
echo

# ------------------ Solicitar IP o nombre del servidor LDAP ------------------

function ask4uri {
# Nos pregunta por la dirección IP o el nombre del dominio
# Si no cumple con la condicón vuelve a preguntar hasta que introduzcamos un valor correcto
while true; do
    echo -e "${CYAN}Por favor introduce la IP o nombre del host del servidor:${RESET} "
    read serverDomain

    # Hace una validación que permite ingresar tanto IPs como nombres de dominio
    if [[ "$serverDomain" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        break  # Entrada válida
    else
        echo -e "${RED}Formato inválido. Debe ser una IP o un nombre de host válido.${RESET}"
    fi
done
}
# ------------------ Ping a el servidor para comprobar si es alcanzable ------------------

function pingURI {

    echo -e "${CYAN}Comprobando conexión con el servidor $serverDomain...${RESET}"
    ping -c 4 "$serverDomain" >> /dev/null  # Comprobamos si nuestro cliente ve al servidor
	
	if [[ $? -eq 0 ]]; then 
		echo -e "${GREEN}Conexión exitosa, continuando con la instalación...${RESET}"
	else 
		echo -e "${RED}Ha habido un problema con la conexión, por favor revise su configuración de red antes de continuar${RESET}"
		exit 1
	fi
	
	echo 
}
# ------------------ Solicitar el nombre del dominio (primer 'dc=') ------------------

function serverName {
# Pregunta por el nombre del servidor es decir el primer dc
# Si no cumple con la condicón vuelve a preguntar hasta que introduzcamos un valor correcto
while true; do
    echo -e "${CYAN}Por favor introduce el nombre del dominio. (Ejemplo: dc='example')${RESET}"
    read serverName

    # La validación se encarga de comprobar que no se introduzcan carácteres especiales que puedan provocar turbulencias
    if [[ "$serverName" =~ ^[a-zA-Z0-9]+$ ]]; then
        break  # Entrada válida
    else
        echo -e "${RED}Nombre de servidor inválido. Solo puedes usar letras y números.${RESET}"
    fi
done

echo

}
# ------------------ Solicitar la extensión del dominio (segundo 'dc=') ------------------

function serverExt {
# Pregunta por la extensión del servidor es decir el primer dc
# Si no cumple con la condicón vuelve a preguntar hasta que introduzcamos un valor correcto
while true; do
    echo -e "${CYAN}Por favor introduce la extensión del dominio (Ejemplo: 'com', 'org', 'net'):${RESET}"
    read extServ
    # Esta validación pide como mínimo dos carácteres y solo permite introducir letras 
    if [[ "$extServ" =~ ^[a-zA-Z]{2,}$ ]]; then
        break  # Entrada válida
    else
        echo -e "${RED}Extensión inválida. Solo se permiten letras y debe tener al menos 2 caracteres.${RESET}"
    fi
done

echo

}
# ------------------ Solicitar el CN del administrador de LDAP ------------------

function serverAdmin {
# Pregunta por el nombre del administrador del servidor
# Si no cumple con la condicón vuelve a preguntar hasta que introduzcamos un valor correcto
while true; do
    echo -e "${CYAN}Por favor introduce el nombre del administrador LDAP (Ejemplo: 'admin' para cn=admin):${RESET}"
    read adminName
    # Esta validación se encarga de que el nombre del administrador no contenga carácteres extraños
    if [[ "$adminName" =~ ^[a-zA-Z0-9._-]+$ ]]; then
        break  # Entrada válida
    else
        echo -e "${RED}Nombre de administrador inválido. Solo puedes usar letras, números, puntos (.), guiones bajos (_) y guiones (-).${RESET}"
    fi
done

echo
}
# ------------------ Solicitar contraseña del administrador de LDAP ------------------

function serverPass {
# Pregunta por el nombre del administrador del servidor
# Si no cumple con la condicón vuelve a preguntar hasta que introduzcamos un valor correcto
while true; do

    echo -e "${CYAN}Por favor proporcione una contraseña para el usuario administrador de LDAP: ${RESET}"
    read -s PassLDAP  # Leer la contraseña sin mostrarla
    echo  # Nueva línea
    # Si la contraseña está vacia nos pide que introduzcamos de nuevo
    if [[ -z "$PassLDAP" ]]; then
        echo -e "${RED}La contraseña no puede estar vacía. Inténtalo de nuevo.${RESET}"
    else
        echo -e "${GREEN}Contraseña aceptada.${RESET}"
        break  # Contraseña válida, salir del bucle
    fi
done

}

# Iniciamos funciones
ask4uri
pingURI
serverName
serverExt
serverAdmin
serverPass

clear 

# ------------------ BLOQUE DE CONTROL PARA VERIFICAR INFORMACIÓN INTRODUCIDA ------------------------

function controlInfo {
echo -e "${CYAN}Información introducida por el usuario:${RESET}"
echo "URI Dirección del servidor LDAP: $serverDomain"
echo "BASE BASE del servidor LDAP: $serverName"
echo "Extensión del dominio: $extServ"
echo "Nombre de administrador: $adminName"
echo "La contraseña no es mostrada por motivos de seguridad, si cree que ha tecleado mal repítalo."
}

controlInfo
sleep 2

# ------------------ Confirmación de la información introducida ------------------------
while true; do
    echo -e "${CYAN}¿Es esta información correcta? (s/n): ${RESET}"
    read infoAnswer

    if [[ "$infoAnswer" =~ ^[Ss]$ ]]; then
        echo -e "${GREEN}Continuando con la instalación...${RESET}"
        break  # Salir del bucle principal si la información es correcta

    elif [[ "$infoAnswer" =~ ^[Nn]$ ]]; then
        echo -e "${CYAN}Por favor, introduce nuevamente los campos que deseas corregir.${RESET}"
       
        while true; do
            echo -e "${CYAN}¿Qué campo deseas corregir? (1: IP/Dominio, 2: Nombre, 3: Extensión, 4: Administrador, 5: Contraseña): ${RESET}"
            read fieldChoice

            case "$fieldChoice" in
                1)
                    ask4uri
                    ;;
                2)
                    serverName
                    ;;
                3)
                    serverExt
                    ;;
                4)
                    serverAdmin
                    ;;
                5)
                    serverPass
                    ;;
                *)
                    echo -e "${RED}Opción no válida. Por favor elige un número entre 1 y 5.${RESET}"
                    continue  # Vuelve a preguntar por el campo
                    ;;
            esac

            # Se muestra información de nuevo para comprobar si la información ha sido reintroducida correctamente
            controlInfo
                       
            break  # Salimos del bucle de corrección para volver al bucle principal
        done
    else
        echo -e "${RED}Opción no válida, responda con 'sS' o 'nN'.${RESET}"
    fi
done

# ------------------ Variables de configuración LDAP ------------------

# Variables definidas por el usuario - Estas variables son usadas en varias partes del script, para la configuración de varias partes
URI="ldap://$serverDomain" 			# URL del servidor
BASE="dc=$serverName,dc=$extServ"   # BASE del servidor
CnServer="cn=$adminName"       		# ADMIN del servidor
CnDnServer="$CnServer,$BASE"  		# Unión del CN y el DN


# Variables para introducir información en ficheros
# Conf PAM
authpam="auth sufficient  pam_ldap.so" 								 # Línea de texto añadida a auth
accpam="account sufficient  pam_ldap.so" 							 # Línea de texto añadida a account
sspam="session required  pam_mkhomedir.so skel=/etc/skel umask=0077" # Línea de texto añadida a session
passpam="password sufficient pam_ldap.so" 							 # Línea de texto añadida a password

# Conf nsswitch.conf
filesldap="files ldap"				# Texto para sustituir en nsswitch.conf

# Conf ldap.conf
LDAPVersion=3						# Versión de LDAP

# Variables con rutas de ficheros
varlibconf="/etc/ldap/ldap.conf" 	# Ruta del archivo de configuración de LDAP
varlibconf2="/etc/ldap.conf"		# Ruta del archivo de configuración LDAP de libnss-ldap
nssconf="/etc/nsswitch.conf"		# Ruta del fichero nsswitch.conf
nslcdconf="/etc/nslcd.conf"  		# Ruta del archivo de configuración de nslcd


# ------------------ Actualización de repositorios e instalación de dependencias ------------------
clear
echo -e "${CYAN}Instalando librerias LDAP, espere por favor...${RESET}"

sudo DEBIAN_FRONTEND=noninteractive apt install -y libnss-ldap libpam-ldap ldap-utils nslcd
				# Instalamos nslcd para acceder por interfaz gráfica

if [[ $? -eq 0 ]]; then 
    echo -e "${GREEN}Instalación completada.${RESET}"
else 
    echo -e "${RED}Ha habido un problema con la instalación${RESET}"
    exit 1
fi

sleep 2 # Retrasamos el script 

# ------------------ Configuración del archivo /etc/ldap/ldap.conf ------------------

# Evitar duplicados en la configuración
if ! grep -q "^URI $URI" "$varlibconf"; then
	sudo sed -i '/^#URI/s/^#//;s|URI.*|URI  '"$URI"'|' "$varlibconf" > /dev/null
fi

if ! grep -q "^BASE $BASE" "$varlibconf"; then
	sudo sed -i '/^#BASE/s/^#//;s|dc=example,dc=com|'"$BASE"'|' "$varlibconf" > /dev/null
fi

if ! grep -q "^LDAP_VERSION" "$varlibconf"; then
	sudo sed -i '/^URI/a LDAP_VERSION 3' "$varlibconf" > /dev/null
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
sudo sed -i "s|^passwd:.*|passwd: $filesldap|" "$nssconf" > /dev/null
sudo sed -i "s|^group:.*|group: $filesldap|" "$nssconf" > /dev/null
sudo sed -i "s|^shadow:.*|shadow: $filesldap|" "$nssconf" > /dev/null

# ------------------ Configuración de /etc/nslcd.conf ------------------
    echo -e "${CYAN}Configurando nslcd...${RESET}"
	
    # Crear o modificar el archivo de configuración nslcd.conf
    cat <<EOL | sudo tee "$nslcdconf" > /dev/null
# Configuración de nslcd
uri ldap://$serverDomain
base $BASE
binddn $CnDnServer
bindpw $PassLDAP
# Opciones de búsqueda
scope sub
# Configuración de caché 
# Uncomment to enable caching
# cache credential
# cache group
# cache passwd
# cache shadow
EOL

echo -e "${GREEN}Archivo /etc/nslcd.conf configurado correctamente.${RESET}"

# Reiniciamos el servicio y comprobamos si se ha reiniciado
sudo systemctl restart nslcd > /dev/null

    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}nslcd reiniciado correctamente.${RESET}"
    else
        echo -e "${RED}Error al reiniciar nslcd...${RESET}"
    fi
	
# Habilitar el servicio nslcd para que inicie al arrancar
sudo systemctl enable nslcd > /dev/null

# ------------------ Verificación de conexión LDAP ------------------
echo -e "${CYAN}Verificando conexión al servidor LDAP...${RESET}"
sleep 2
ldapsearch -x -D "$CnDnServer" -W -b "$BASE" >> /dev/null
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}Conexión LDAP exitosa.${RESET}"
else
    echo -e "${RED}Error en la conexión LDAP. Verifica la configuración.${RESET}"
    exit 1
fi

# Preguntar al cliente el uid de un usuario para verificar la configuración 
echo -e "${CYAN}Para verificar la unión, introduzca el uid de un usuario del servidor: ${RESET}" 
sleep 1

while true; do
read uiduserldap 
echo
# Obtener la información del usuario del servidor LDAP, si es correcta inicia sesión, si no existe vuelve a preguntar por otro usuario.
sudo getent passwd "$uiduserldap" >> /dev/null 

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}Accediendo a el sistema como $uiduserldap... ${RESET}"
    sleep 2
    su - $uiduserldap
    break

else 
    echo -e "${RED}El usuario introducido no existe, intentalo de nuevo...${RESET}"
    sleep 1 
fi

done
