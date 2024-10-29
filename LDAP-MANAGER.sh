#!/bin/bash

# Script diseñado y desarrollado por Miguel Hernández
# -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# ------------------ Definición de colores para texto ------------------
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'
RESET='\033[0m'

# ------------------ Check previo para ejecutar script como root ----------------
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script debe ejecutarse como root${RESET}"
   exit 1
fi

# Funciones que están presentes en ciertas partes del script
# Funciones para comprobar si existen o no objetos de x tipo en el servidor
# Usuarios
function userExists {
    if ! ldapsearch -x -LLL -b "$baseDN" "(objectClass=posixAccount)" | grep -q "^dn:"; then
        echo -e "${RED}No existen usuarios en el servidor${RESET}" ;sleep 1 ;clear
        return 1  # Retorna 1 en caso de que no existan usuarios
    else
        return 0  # Retorna 0 si existen usuarios
    fi
}

# Grupos
function groupExists {
    if ! ldapsearch -xLLL -b "$baseDN" "(objectClass=posixGroup)" | grep -q "^dn:"; then
        echo -e "${RED}No existen grupos en el servidor${RESET}"; sleep 1; clear
        return 1  # Retorna 1 en caso de que no existan grupos
    else
        return 0  # Retorna 0 si existen grupos
    fi
}

# Unidades organizativas
function OUExists {
    if ! ldapsearch -xLLL -b "$baseDN" "(objectClass=organizationalUnit)" | grep -q "^dn:"; then
        echo -e "${RED}No existen OUs en el servidor${RESET}"; sleep 1; clear
        return 1  # Retorna 1 en caso de que no existan OUs
    else
        return 0  # Retorna 0 si existen OUs
    fi
}

# Función para preguntar a el usuario si quiere repetir una acción
function repeatAction {
   sleep 1; echo -e "${CYAN}Si desea repetir la acción pulse 1 de lo contrario pulse intro${RESET}"; read action
    if [ "$action" == '1' ]; then 
        return 1 # Se repite la acción
    elif [ -z "$action" ]; then
        return 0; clear # De vuelta a el menú principal
    fi 
}

# ----------------------- Introducir Info del Servidor ----------------------------

function serverInfo {
    clear
    echo -e "${CYAN}Introduzca la información del servidor${RESET}"
    read -p "NOMBRE del servidor (dc='example'): " servName
    read -p "EXTENSIÓN del servidor (dc='extension'): " servExt
    read -p "ADMIN del servidor (cn=example): " superAdmin
    read -sp "CONTRASEÑA del administrador del servidor: " passAdmin
    echo  # Salto de línea para que no se junte con la entrada de la contraseña
    clear
    while true; do
        echo -e "${CYAN}Información introducida${RESET}"
        echo "NOMBRE del servidor (dc='example'): $servName"
        echo "EXTENSIÓN del servidor (dc='extensión'): $servExt"
        echo "ADMIN del servidor (cn=example): $superAdmin"
        echo "CONTRASEÑA del administrador del servidor: ${passAdmin:0:1}***${passAdmin: -1}"
        echo -e "${CYAN}¿Es esta información correcta? (s/n)${RESET}"
        read answerI
        if [[ "$answerI" =~ ^[sS]$ ]]; then
            break  # Continua con el script
        elif [[ "$answerI" =~ ^[nN]$ ]]; then
            echo -e "${YELLOW}Seleccione el dato incorrecto${RESET}"
            echo -e "${WHITE}1) NOMBRE del servidor${RESET}"
            echo -e "${WHITE}2) EXTENSIÓN del servidor${RESET}"
            echo -e "${WHITE}3) ADMIN del servidor${RESET}"
            echo -e "${WHITE}4) CONTRASEÑA del servidor${RESET}"
            read infoAnswer
            case $infoAnswer in
                1) read -p "NOMBRE del servidor (dc='example'): " servName; clear;;
                2) read -p "EXTENSIÓN del servidor (dc='extension'): " servExt; clear;;
                3) read -p "ADMIN del servidor (cn=example): " superAdmin; clear;;
                4) read -sp "CONTRASEÑA del administrador del servidor: " passAdmin ; echo "" ; clear;;
                *) echo -e "${RED}Opción no valida, introduzca del [1-4]${RESET}" ;;
            esac
        else
            echo -e "${RED}La opción "$answerI" no es válida, responda con s o n${RESET}"
        fi
    done
    clear  # Limpiamos la terminal
}

serverInfo  # Ejecutamos la función que pide información al administrador del servidor

# Variables del servidor obtenidas por la información introducida
baseDN="dc=$servName,dc=$servExt"
bindDN="cn=$superAdmin,$baseDN"
bindPW="$passAdmin"

# Variables para el servidor para suplementar funciones 
availableOUs=$(ldapsearch -xLLL -b "$baseDN" "(objectClass=organizationalUnit)" ou | grep ^ou: | awk '{print $2}')
availableGroups=$(ldapsearch -xLLL -b "$baseDN" "(objectClass=posixGroup)" cn | grep ^cn: | awk '{print $2}')
# -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Funciones auxiliares de las funciones para consultar el servidor

# Funciones para consultar el servidor
# Función para consultar usuarios 
function Users {
    clear
    echo -e "${CYAN}Usuarios del servidor: ${RESET}"
    userExists
    if [[ $? -ne 0 ]]; then
        return 1  # Si no hay usuarios, salir de esta función también
    fi
    ldapsearch -xLLL -b "$baseDN" "(objectClass=inetOrgPerson)" uid
    echo -e "${CYAN}Para ver información detallada del usuario introduzca su uid${RESET}"
    while true; do
        read uid
        echo
        if [[ -z "$uid" ]]; then
            echo -e "${RED}El uid no puede estar vacío, inténtelo de nuevo${RESET}"
        elif ! ldapsearch -xLLL -b "$baseDN" "uid=$uid" > /dev/null 2>&1; then
            echo -e "${RED}El usuario $uid no existe${RESET}"
        else
            break
        fi
    done

    clear
    echo -e "${CYAN}¿Desea ver la información en formato 'amigable' o 'ampliado'?${RESET}"
    echo -e "${WHITE}1) Amigable${RESET}"
    echo -e "${WHITE}2) Ampliado${RESET}"
    read formatChoice

    if [[ "$formatChoice" == "1" ]]; then
        echo -e "${CYAN}Información amigable de ${WHITE}$uid${RESET}"
        ldapsearch -xLLL -b "$baseDN" "uid=$uid" | grep -E "(^dn:|^objectClass:|^cn:|^sn:|^givenName:|^mail:|^uidNumber:|^gidNumber:|^homeDirectory:|^shadowExpire:|^displayName:|^uid:|^intials:|^telephoneNumber:|)" | sed -e 's/cn:/Nombre completo:/g' -e 's/sn:/Apellido:/g' -e 's/givenName:/Nombre:/g' -e 's/mail:/E-Mail:/g' -e 's/uidNumber:/ID de usuario único:/g' -e 's/gidNumber:/ID de grupo asignado:/g' -e 's/homeDirectory:/Directorio Personal:/g' -e 's/dn:/Ubicación:/g' -e 's/objectClass:/Clase de objeto:/g' -e 's/shadowExpire:/Vencimiento de la cuenta:/g' -e 's/displayName:/Nombre mostrado por pantalla:/g' -e 's/initials:/Iniciales:/g' -e 's/uid:/Identificador del usuario:/g' -e 's/telephoneNumber:/Número de teléfono:/g' 
    elif [[ "$formatChoice" == "2" ]]; then
        echo -e "${CYAN}Información ampliada de ${WHITE}$uid${RESET}"
        ldapsearch -xLLL -b "$baseDN" "uid=$uid"
    else
        echo -e "${RED}Opción no válida, mostrando información ampliada por defecto.${RESET}"
        echo -e "${CYAN}Información ampliada de $uid${RESET}"
        ldapsearch -xLLL -b "$baseDN" "uid=$uid"
    fi

    echo 
    repeatAction
    if [ $? -eq 1 ]; then
        Users
    else 
        clear; return
    fi
}

# Función para consultar grupos
function Groups {
    clear
    echo -e "${CYAN}Grupos del servidor: ${RESET}"
    groupExists
     if [[ $? -ne 0 ]]; then
        return 1  # Si no hay usuarios, salir de esta función también
    fi
    ldapsearch -xLLL -b "$baseDN" "(objectClass=posixGroup)" cn gidNumber
    echo -e "${CYAN}Para ver información detallada del grupo introduzca su cn${RESET}"
    while true; do
        read cn
        echo
        if [[ -z "$cn" ]]; then
            echo -e "${RED}El cn no puede estar vacío, inténtelo de nuevo${RESET}"
        elif ! ldapsearch -xLLL -b "$baseDN" "cn=$cn" > /dev/null 2>&1; then
            echo -e "${RED}El grupo $cn no existe${RESET}"
        else
            break
        fi
    done

    clear
    echo -e "${CYAN}¿Desea ver la información en formato 'amigable' o 'ampliado'?${RESET}"
    echo -e "${WHITE}1) Amigable${RESET}"
    echo -e "${WHITE}2) Ampliado${RESET}"
    read formatChoice

    if [[ "$formatChoice" == "1" ]]; then
        echo -e "${CYAN}Información amigable de $cn${RESET}"
        ldapsearch -xLLL -b "$baseDN" "cn=$cn" | grep -E "(^cn:|^dn:|^objectClass:|^gidNumber:|^description:|^displayName:|^memberUid:|)" | sed -e 's/cn:/Nombre del grupo:/g' -e 's/gidNumber:/Número de grupo:/g' -e 's/description:/Descripción:/g' -e 's/memberUid:/Miembro que pertenece a el grupo:/g' -e 's/dn:/Ubicación:/g' -e 's/objectClass:/Clase de objeto:/g'
    elif [[ "$formatChoice" == "2" ]]; then
        echo -e "${CYAN}Información ampliada de $cn${RESET}"
        ldapsearch -xLLL -b "$baseDN" "cn=$cn"
    else
        echo -e "${RED}Opción no válida, mostrando información ampliada por defecto.${RESET}"
        echo -e "${CYAN}Información ampliada de $cn${RESET}"
        ldapsearch -xLLL -b "$baseDN" "cn=$cn"
    fi

    echo
    repeatAction
    if [ $? -eq 1 ]; then
        Groups
    else 
        clear; return
    fi
}

# Función para reubicar OUs en el servidor
function OUs {
    clear
    echo -e "${CYAN}OUs del servidor: ${RESET}"
    OUExists
    if [[ $? -ne 0 ]]; then
        return 1  # Si no hay usuarios, salir de esta función también
    fi
    ldapsearch -xLLL -b "$baseDN" "(objectClass=organizationalUnit)" ou | grep "^ou: "
    echo -e "${CYAN}Para ver información detallada de la OU introduzca su ou${RESET}"
    while true; do
        read ou
        echo
        if [[ -z "$ou" ]]; then
            echo -e "${RED}El ou no puede estar vacío, inténtelo de nuevo${RESET}"
        elif ! ldapsearch -xLLL -b "$baseDN" "ou=$ou" > /dev/null 2>&1; then
            echo -e "${RED}La OU $ou no existe${RESET}"
        else
            break
        fi
    done

    clear
    echo -e "${CYAN}¿Desea ver la información en formato 'amigable' o 'ampliado'?${RESET}"
    echo -e "${WHITE}1) Amigable${RESET}"
    echo -e "${WHITE}2) Ampliado${RESET}"
    read formatChoice

    if [[ "$formatChoice" == "1" ]]; then
        echo -e "${CYAN}Información amigable de la unidad organizativa ${WHITE}$ou${RESET}"
        ldapsearch -xLLL -b "$baseDN" "ou=$ou" | grep -E "(^ou:|^description:|^dn:|^objectClass:|^l:|^st:|^postalCode:|)" | sed -e 's/ou:/Nombre de la unidad organizativa:/g' -e 's/description:/Descripción:/g' -e 's/dn:/Ubicación:/g' -e 's/objectClass:/Clase de objeto:/g' -e 's/l:/Localidad donde se sitúa:/g' -e 's/st:/Estado o país donde se situa:/g' -e 's/postalCode:/Código postal:/g'
    elif [[ "$formatChoice" == "2" ]]; then
        echo -e "${CYAN}Información ampliada de la unidad organizativa ${WHITE}$ou${RESET}"
        ldapsearch -xLLL -b "$baseDN" "ou=$ou"
    else
        echo -e "${RED}Opción no válida, mostrando información ampliada por defecto.${RESET}"
        echo -e "${CYAN}Información ampliada de la unidad organizativa ${WHITE}$ou${RESET}"
        ldapsearch -xLLL -b "$baseDN" "ou=$ou"
    fi

    echo
    repeatAction
    if [ $? -eq 1 ]; then
        OUs
    else 
        clear; return
    fi
}
# -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Funciones para la reubicación de los objetos del servidor

# Funciones auxiliares para las funciones de la reubicación de objetos 
# Función auxiliar de ubiUser para cambiar el gidNumber a la hora de mover un usuario de grupo principal
function changeGidNumber {
    echo -e "${CYAN}Grupos disponibles en el servidor:${RESET}"
    ldapsearch -x -LLL -b "$baseDN" "(objectClass=posixGroup)" cn | grep "^cn: " | awk '{print $2}'
    echo -e "${CYAN}Introduzca el CN del nuevo grupo: ${RESET}"
    read cnGroup
    local newGid=$(ldapsearch -x -LLL -b "$baseDN" "cn=$cnGroup" gidNumber | grep "gidNumber" | awk '{print $2}')
    
    # Usar el CN del usuario proporcionado previamente en la función 'ubiUser'
    echo -e "${CYAN}Buscando UID del usuario $1...${RESET}"
    
    # Buscar UID del usuario utilizando el CN proporcionado como parámetro
    uidUser=$(ldapsearch -x -LLL -b "$baseDN" "(cn=$1)" uid | grep "^uid: " | awk '{print $2}')
    
    if [[ -z "$uidUser" ]]; then
        echo -e "${RED}No se pudo encontrar el UID para el usuario con CN: $1.${RESET}"
        return
    fi

    echo -e "${CYAN}Cambiando el grupo principal del usuario $uidUser ($1) al grupo $cnGroup con gidNumber $newGid...${RESET}"
    userDN=$(ldapsearch -x -LLL -b "$baseDN" "uid=$uidUser" dn | grep "^dn: " | awk '{print $2}')
    cat <<EOF > changeUserP.ldif
dn: $userDN
changetype: modify
replace: gidNumber
gidNumber: $newGid
EOF
    if ldapmodify -x -D "$bindDN" -w "$bindPW" -f changeUserP.ldif >> /dev/null; then
        echo -e "${GREEN}El grupo principal del usuario $uidUser ($1) ha sido cambiado al grupo $cnGroup con éxito.${RESET}"
        ldapsearch -x -LLL -b "$baseDN" "uid=$uidUser"
    else
        echo -e "${RED}El grupo principal del usuario $uidUser no ha sido cambiado.${RESET}"
    fi
    rm changeUserP.ldif >> /dev/null 2>&1
    sleep 1
    clear
}

# Función para reubicar un usuario
function ubiUser {
    userExists # Comprobamos si existen usuarios o no
    if [[ $? -ne 0 ]]; then
        return 1  # Si no hay grupos, salir de esta función también
    fi
    echo -e "${CYAN}Usuarios del servidor: ${RESET}"
    ldapsearch -xLLL -b "$baseDN" "(objectClass=posixAccount)" cn
    echo
    echo -e "${CYAN}Introduzca el CN del usuario que quiere reubicar: ${RESET}"
    read user

    # Obtener el DN del usuario
    userDN=$(ldapsearch -xLLL -b "$baseDN" "(cn=$user)" dn | grep "^dn: " | awk '{print $2}')
    if [[ -z "$userDN" ]]; then
        echo -e "${RED}No se pudo encontrar el DN para el usuario $user.${RESET}"
        return
    fi

    echo -e "${CYAN}¿Donde quiere reubicar el usuario?${RESET}"
    echo -e "${WHITE}1) Grupo (Introduzca el nombre del grupo)${RESET}"
    echo -e "${WHITE}2) Unidad Organizativa (Introduzca el nombre de la OU)${RESET}"
    echo -e "${WHITE}3) Raíz del servidor${RESET}"
    echo -e "${WHITE}4) Cambiar de grupo (gidNumber)${RESET}"
    read choice

    case $choice in
        1)  
            echo -e "${CYAN}Grupos disponibles en el servidor${RESET}"
            echo $availableGroups
            echo -e "${WHITE}Introduzca el nombre del grupo: ${RESET}"
            read group
            newSuperiorDN="cn=$group,ou=grupos,$baseDN"
            clear
            ;;
        2)  
            echo -e "${CYAN}OUs disponibles en el servidor${RESET}"
            echo $availableOUs
            echo -e "${WHITE}Introduzca el nombre de la OU: ${RESET}"
            read ou
            newSuperiorDN="ou=$ou,$baseDN"
            clear
            ;;
        3)
            newSuperiorDN="$baseDN"
            clear
            ;;
        4)
            # Llamar a la función changeGidNumber con el CN del usuario como parámetro
            changeGidNumber "$user"
            clear
            return
            ;;
        *)
            echo -e "${RED}Opción no válida. Inténtelo de nuevo.${RESET}"
            return
            ;;
    esac

    # Confirmar reubicación del usuario
    echo -e "${YELLOW}¿Está seguro de que desea reubicar el usuario $user a $newSuperiorDN? Escriba 'si' para confirmar o 'cancelar' para detener.${RESET}"
    read -r confirmMove
    if [[ "$confirmMove" != "si" ]]; then
        echo -e "${RED}Operación cancelada. No se ha reubicado el usuario.${RESET}"
        return
    fi

    # Mover el usuario
    ldapmodify -x -D "$bindDN" -w "$bindPW" <<EOF >> /dev/null 
dn: $userDN
changetype: moddn
newrdn: $(echo $userDN | awk -F, '{print $1}')
deleteoldrdn: 1
newSuperior: $newSuperiorDN
EOF
    sleep 2
    echo -e "${GREEN}El usuario $user ha sido reubicado a $newSuperiorDN con éxito.${RESET}"
    clear
}

# Función para reubicar grupos en el servidor 
function ubiGroup {
    groupExists # Comprobamos si existen grupos
    if [[ $? -ne 0 ]]; then
        return 1  # Si no hay grupos, salir de esta función también
    fi
    echo -e "${CYAN}Grupos del servidor: ${RESET}"
    ldapsearch -xLLL -b "$baseDN" "(objectClass=posixGroup)" cn
    echo
    echo -e "${CYAN}Seleccione el grupo que quiere reubicar: ${RESET}"
    read group

    # Obtener el DN del grupo
    groupDN=$(ldapsearch -xLLL -b "$baseDN" "(cn=$group)" dn | grep "^dn: " | awk '{print $2}')
    if [[ -z "$groupDN" ]]; then
        echo -e "${RED}No se pudo encontrar el DN para el grupo $group.${RESET}"
        return
    fi

    echo -e "${CYAN}¿Dónde quiere reubicar el grupo?${RESET}"
    echo -e "${WHITE}1) Grupo (Introduzca el nombre del grupo)${RESET}"
    echo -e "${WHITE}2) Unidad Organizativa (Introduzca el nombre de la OU)${RESET}"
    echo -e "${WHITE}3) Raíz del servidor${RESET}"
    read choice

    case $choice in
        1)  
            echo -e "${CYAN}Grupos disponibles en el servidor${RESET}"
            echo $availableGroups
            echo -e "${WHITE}Introduzca el nombre del grupo: ${RESET}"
            read newGroup
            newSuperiorDN="cn=$newGroup,ou=grupos,$baseDN"
            clear
            ;;
        2)
            echo -e "${CYAN}OUs disponibles en el servidor${RESET}"
            echo $availableOUs
            echo -e "${WHITE}Introduzca el nombre de la OU: ${RESET}"
            read ou
            newSuperiorDN="ou=$ou,$baseDN"
            clear
            ;;
        3)
            newSuperiorDN="$baseDN"
            clear
            ;;
        *)
            echo -e "${RED}Opción no válida. Inténtelo de nuevo.${RESET}"
            clear
            return
            ;;
    esac

    # Confirmar reubicación del grupo
    echo -e "${YELLOW}¿Está seguro de que desea reubicar el grupo $group a $newSuperiorDN? Escriba 'si' para confirmar o 'cancelar' para detener.${RESET}"
    read -r confirmMove
    if [[ "$confirmMove" != "si" ]]; then
        echo -e "${RED}Operación cancelada. No se ha reubicado el grupo.${RESET}"
        return
    fi

    # Mover el grupo
    ldapmodify -x -D "$bindDN" -w "$bindPW" <<EOF >> /dev/null
dn: $groupDN
changetype: moddn
newrdn: $(echo $groupDN | awk -F, '{print $1}')
deleteoldrdn: 1
newSuperior: $newSuperiorDN
EOF

    echo -e "${GREEN}El grupo $group ha sido reubicado a $newSuperiorDN con éxito.${RESET}"
}

# Función para reubicar OUs en el servidor 
function ubiOUs {
    OUExists
    if [[ $? -ne 0 ]]; then
        return 1  # Si no hay grupos, salir de esta función también
    fi
    echo -e "${CYAN}OUs del servidor: ${RESET}"
    ldapsearch -xLLL -b "$baseDN" "(objectClass=organizationalUnit)" ou
    echo
    echo -e "${CYAN}Seleccione la OU que quiere reubicar: ${RESET}"
    read ou

    # Obtener el DN de la OU
    ouDN=$(ldapsearch -xLLL -b "$baseDN" "(ou=$ou)" dn | grep "^dn: " | awk '{print $2}')
    if [[ -z "$ouDN" ]]; then
        echo -e "${RED}No se pudo encontrar el DN para la OU $ou.${RESET}"
        return
    fi

    echo -e "${CYAN}¿Dónde quiere reubicar la OU?${RESET}"
    echo -e "${WHITE}1) Grupo (Introduzca el nombre del grupo)${RESET}"
    echo -e "${WHITE}2) Unidad Organizativa (Introduzca el nombre de la OU)${RESET}"
    echo -e "${WHITE}3) Raíz del servidor${RESET}"
    read choice

    case $choice in
        1)
            echo -e "${CYAN}Grupos disponibles en el servidor${RESET}"
            echo $availableGroups
            echo -e "${CYAN}Introduzca el nombre del grupo: ${RESET}"
            read newGroup
            newSuperiorDN="cn=$newGroup,ou=grupos,$baseDN"
            clear
            ;;
        2)
            echo -e "${CYAN}OUs disponibles en el servidor${RESET}"
            echo $availableOUs
            echo -e "${WHITE}Introduzca el nombre de la OU: ${RESET}"
            read newOU
            newSuperiorDN="ou=$newOU,$baseDN"
            clear
            ;;
        3)
            newSuperiorDN="$baseDN"
            clear
            ;;
        *)
            echo -e "${RED}Opción no válida. Inténtelo de nuevo.${RESET}"
            clear
            return
            ;;
    esac

    # Confirmar reubicación de la OU
    echo -e "${YELLOW}¿Está seguro de que desea reubicar la OU $ou a $newSuperiorDN? Escriba 'si' para confirmar o 'cancelar' para detener.${RESET}"
    read -r confirmMove
    if [[ "$confirmMove" != "si" ]]; then
        echo -e "${RED}Operación cancelada. No se ha reubicado la OU.${RESET}"
        return
    fi

    # Mover la OU
    ldapmodify -x -D "$bindDN" -w "$bindPW" <<EOF >> /dev/null
dn: $ouDN
changetype: moddn
newrdn: $(echo $ouDN | awk -F, '{print $1}')
deleteoldrdn: 1
newSuperior: $newSuperiorDN
EOF

    echo -e "${GREEN}La OU $ou ha sido reubicada a $newSuperiorDN con éxito.${RESET}"
}

# -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Funciones para la eliminación de objetos

# Funciones auxiliares para las funciones de la eliminación de los objetos

# Función que comprueba si una OU existe en el servidor
# Cuando la llamamos en la función de eliminación de OUs lo hacemos para que a la hora de eliminar la OU, si tiene grupos o usuarios dentro de ella
# Esta crea las OUs usuarios y grupos si no están en el servidor para mover ahí a los usuarios
function ensureOUExists {
    ouName=$1
    ouFullDN="ou=$ouName,$baseDN"
    if ! ldapsearch -x -b "$baseDN" "(ou=$ouName)" | grep -q "^ou: "; then
        echo -e "${CYAN}La OU $ouName no existe. Creándola...${RESET}"
        ldapadd -x -D "$bindDN" -w "$bindPW" <<EOF
dn: $ouFullDN
objectClass: top
objectClass: organizationalUnit
ou: $ouName
EOF
        echo -e "${GREEN}OU $ouName creada exitosamente.${RESET}"
    else
        echo -e "${CYAN}La OU $ouName ya existe.${RESET}"
    fi
}

# Función que verifica si existe un grupo y si no existe lo crea y a parte genera un gidNumber aleatorio 
function ensureGroupExists {
    groupName=$1
    groupFullDN="cn=$groupName,$baseDN"
    if ! ldapsearch -x -b "$baseDN" "(cn=$groupName)" | grep -q "^cn: "; then
        echo -e "${CYAN}El grupo $groupName no existe. Creándolo...${RESET}"
        gidNumber=$(($(ldapsearch -xLLL -b "$baseDN" "(objectClass=posixGroup)" gidNumber | awk '{print $2}' | sort -n | tail -n 1) + 1))  # Genera un gidNumber único
        ldapadd -x -D "$bindDN" -w "$bindPW" <<EOF
dn: $groupFullDN
objectClass: top
objectClass: posixGroup
cn: $groupName
gidNumber: $gidNumber
EOF
        echo -e "${GREEN}Grupo $groupName creado exitosamente.${RESET}"
    else
        echo -e "${CYAN}El grupo $groupName ya existe.${RESET}"
    fi
}

# Función que elimina usuarios del servidor
function removeUser {
    # Si no hay usuarios te echa para atrás
    userExists
    if [[ $? -ne 0 ]]; then
        return 1  # Si no hay grupos, salir de esta función también
    fi

    clear
    echo -e "${CYAN}¿Qué usuario desea eliminar? Introduzca su cn: ${RESET}"
    # Mostrar los nombres de los usuarios
    ldapsearch -xLLL -b "$baseDN" "(objectClass=inetOrgPerson)" | grep "^cn"
    echo
    while true; do
        read -r user
        # Validar que el usuario no esté vacío
        if [[ -z "$user" ]]; then
            echo -e "${RED}Usuario vacío, no se puede tratar, inténtelo de nuevo${RESET}"
            continue
        elif ! ldapsearch -x -b "$baseDN" "(cn=$user)" | grep -q "^cn: "; then
            echo -e "${RED}El usuario $user no existe, inténtelo de nuevo${RESET}"
            continue
        else
            # Obtener el DN completo del usuario
            userDN=$(ldapsearch -xLLL -b "$baseDN" "(cn=$user)" dn | grep "^dn: " | awk '{print $2}')
            if [[ -z "$userDN" ]]; then
                echo -e "${RED}No se pudo encontrar el DN para el usuario $user.${RESET}"
                break
            fi

            # Confirmar eliminación del usuario
            echo -e "${YELLOW}¿Desea eliminar al usuario $user del servidor? Escriba 'si' para confirmar o 'cancelar' para detener.${RESET}"
            read -r confirmDelete
            if [[ "$confirmDelete" != "si" ]]; then
                echo -e "${RED}Operación cancelada. No se ha eliminado al usuario $user del servidor.${RESET}"
                echo
                break
            fi

            # Eliminar el usuario si se ha confirmado
            ldapdelete -x -D "$bindDN" -w "$bindPW" "$userDN"
            echo -e "${GREEN}El usuario $user ha sido eliminado del servidor.${RESET}"
            break
        fi
    done
    repeatAction
    if [ $? -eq 1 ]; then
        removeUser
    else 
        clear; return
    fi
}

# Función para la eliminación de grupos
function removeGroup {
    # Verifica si existen grupos
    groupExists
    if [[ $? -ne 0 ]]; then
        return 1  # Si no hay grupos, salir de esta función también
    fi

    echo -e "${CYAN}¿Qué grupo desea eliminar?: ${RESET}"
    # Mostrar los nombres de los grupos
    ldapsearch -xLLL -b "$baseDN" "(objectClass=posixGroup)" | grep "^cn:"
    echo
    while true; do
        read -r grupo
        # Validar que el grupo no esté vacío
        if [[ -z "$grupo" ]]; then
            echo -e "${RED}Grupo vacío, no se puede tratar, inténtelo de nuevo${RESET}"
        elif ! ldapsearch -x -b "$baseDN" "(cn=$grupo)" | grep -q "^cn: "; then
            echo -e "${RED}El grupo ${WHITE}$grupo${RESET} no existe, inténtelo de nuevo${RESET}"
        else
            clear

            # Obtener el DN completo del grupo
            groupDN=$(ldapsearch -xLLL -b "$baseDN" "(cn=$grupo)" dn | grep "^dn: " | awk '{print $2}')
            echo -e "${CYAN}DN del grupo a eliminar: ${WHITE}$groupDN${RESET}" 

            if [[ -z "$groupDN" ]]; then
                echo -e "${RED}No se pudo encontrar el DN para el grupo $grupo.${RESET}"
                break
            fi

            # Crear OUs y grupo de respaldo si no existen
            ensureOUExists "usuarios"
            ensureOUExists "grupos"
            ensureOUExists "OUs"
            ensureGroupExists "usuarios"

            # Obtener usuarios que pertenecen al grupo a eliminar
            usuarios=$(ldapsearch -xLLL -b "$baseDN" "(memberOf=$groupDN)" uid | grep "^uid:" | awk '{print $2}')
            if [[ -z "$usuarios" ]]; then
                echo -e "${WHITE}No hay usuarios pertenecientes al grupo $grupo.${RESET}"
            else
                echo -e "${CYAN}Usuarios que pertenecen al grupo $grupo:${RESET}"
                echo "$usuarios"
            fi

            # Confirmar eliminación
            echo -e "${YELLOW}¿Está seguro de que desea eliminar el grupo $grupo? Escriba 'si' para confirmar o 'cancelar' para detener.${RESET}"
            read -r confirm
            if [[ "$confirm" == "cancelar" ]]; then
                echo -e "${RED}Operación cancelada. No se ha eliminado el grupo $grupo.${RESET}"
                break
            fi

            # Mover usuarios al grupo "usuarios" y cambiar su gidNumber
            usuarios_gidNumber=$(ldapsearch -xLLL -b "$baseDN" "(cn=usuarios)" gidNumber | grep "^gidNumber:" | awk '{print $2}')
            for usuario in $usuarios; do
                echo -e "${CYAN}Moviendo usuario $usuario al grupo 'usuarios' y actualizando su gidNumber${RESET}"
                ldapmodify -x -D "$bindDN" -w "$bindPW" <<EOF
dn: uid=$usuario,$baseDN
changetype: modify
replace: gidNumber
gidNumber: $usuarios_gidNumber
EOF
            done

            # Mover OUs colgantes dentro del grupo eliminado a 'ou=OUs'
            OUs_colgantes=$(ldapsearch -x -b "$groupDN" "(objectClass=organizationalUnit)" dn | grep "^dn: " | awk '{print $2}')
            for OUs_dn in $OUs_colgantes; do
                echo -e "${CYAN}Moviendo OU colgante $OUs_dn a la OU 'OUs'${RESET}"
                ldapmodify -x -D "$bindDN" -w "$bindPW" <<EOF
dn: $(echo $OUs_dn | sed -r 's/([=,+])/\\\1/g')
changetype: moddn
newrdn: ou=$(echo $OUs_dn | grep -oP 'ou=\K[^,]+')
deleteoldrdn: 1
newSuperior: ou=OUs,$baseDN
EOF
            done

            # Intentar eliminar el grupo original después de mover todos los objetos
            if ! ldapdelete -x -D "$bindDN" -w "$bindPW" "$groupDN"; then
                echo -e "${RED}Error al eliminar el grupo $grupo: DN no válido o permisos insuficientes.${RESET}"
            else
                sleep 1
                echo -e "${GREEN}El grupo $grupo ha sido eliminado.${RESET}"
            fi
            break
        fi
    done
    repeatAction
    if [ $? -eq 1 ]; then
        removeGroup
    else 
        clear; return
    fi
}

# Función para la eliminación de OUs 
function removeOU {
    # Verifica si existen OUs
    OUExists
    if [[ $? -ne 0 ]]; then
        return 1
    fi

    clear
    echo -e "${CYAN}¿Qué OU desea eliminar?: ${RESET}"
    ldapsearch -xLLL -b "$baseDN" "(objectClass=organizationalUnit)" | grep "^ou"
    echo
    while true; do
        read -r ou
        if [[ -z "$ou" ]]; then
            echo -e "${RED}OU vacía, no se puede tratar, inténtelo de nuevo${RESET}"
        elif ! ldapsearch -x -b "$baseDN" "(ou=$ou)" | grep -q "^ou: "; then
            echo -e "${RED}La OU $ou no existe, inténtelo de nuevo${RESET}"
        else
            ouDN=$(ldapsearch -xLLL -b "$baseDN" "(ou=$ou)" dn | grep "^dn: " | awk '{print $2}')
            if [[ -z "$ouDN" ]]; then
                echo -e "${RED}No se pudo encontrar el DN para la OU $ou.${RESET}"
                break
            fi

            echo -e "${CYAN}Usuarios en la OU $ou: ${RESET}"
            usuarios_colgantes=$(ldapsearch -x -b "$ouDN" "(objectClass=inetOrgPerson)" dn | grep "^dn: " | awk '{print $2}')
            echo "${usuarios_colgantes:-No hay usuarios en la OU $ou.}"

            echo -e "${CYAN}Grupos en la OU $ou: ${RESET}"
            grupos_colgantes=$(ldapsearch -x -b "$ouDN" "(objectClass=posixGroup)" dn | grep "^dn: " | awk '{print $2}')
            echo "${grupos_colgantes:-No hay grupos en la OU $ou.}"

            echo -e "${CYAN}OUs en la OU $ou: ${RESET}"
            OUs_colgantes=$(ldapsearch -xLLL -b "$ouDN" "(objectClass=organizationalUnit)" dn | grep -v "^dn: $ouDN$" | awk '{print $2}')
            echo "${OUs_colgantes:-No hay OUs en la OU $ou.}"

            echo -e "${YELLOW}¿Está seguro de que desea eliminar la OU $ou? Escriba 'si' para confirmar o 'cancelar' para detener.${RESET}"
            read -r confirmDelete
            if [[ "$confirmDelete" != "si" ]]; then
                echo -e "${RED}Operación cancelada. No se ha eliminado la OU $ou.${RESET}"
                break
            fi

            ensureOUExists "usuarios"
            ensureOUExists "grupos"
            ensureOUExists "OUs"

            for usuario_dn in $usuarios_colgantes; do
                echo -e "${CYAN}Moviendo usuario colgante $usuario_dn a la OU 'usuarios'${RESET}"
                ldapmodify -x -D "$bindDN" -w "$bindPW" <<EOF > /dev/null 
dn: $usuario_dn
changetype: moddn
newrdn: uid=$(echo $usuario_dn | grep -oP 'uid=\K[^,]+')
deleteoldrdn: 1
newSuperior: ou=usuarios,$baseDN
EOF
            done
            sleep 1

            for grupo_dn in $grupos_colgantes; do
                echo -e "${CYAN}Moviendo grupo colgante $grupo_dn a la OU 'grupos'${RESET}"
                ldapmodify -x -D "$bindDN" -w "$bindPW" <<EOF > /dev/null
dn: $grupo_dn
changetype: moddn
newrdn: cn=$(echo $grupo_dn | grep -oP 'cn=\K[^,]+')
deleteoldrdn: 1
newSuperior: ou=grupos,$baseDN
EOF
            done

            for OUs_dn in $OUs_colgantes; do
                echo -e "${CYAN}Moviendo OU colgante $OUs_dn a la OU 'OUs'${RESET}"
                ldapmodify -x -D "$bindDN" -w "$bindPW" <<EOF > /dev/null
dn: $(echo $OUs_dn | sed -r 's/([=,+])/\\\1/g')
changetype: moddn
newrdn: ou=$(echo $OUs_dn | grep -oP 'ou=\K[^,]+')
deleteoldrdn: 1
newSuperior: ou=OUs,$baseDN
EOF
            done
            sleep 3

            # Imprimir el DN de la OU antes de eliminarla
            echo -e "${YELLOW}Eliminando OU con DN: $ouDN${RESET}"
            ldapdelete -x -D "$bindDN" -w "$bindPW" "$ouDN"
            echo -e "${GREEN}La OU $ou ha sido eliminada del servidor.${RESET}"
            break
        fi
    done
    repeatAction
    if [ $? -eq 1 ]; then
        removeOU
    else 
        clear; return
    fi
}
# -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Funciones para la modificación de objetos

# Funciones para la modificación de los usuarios

# Función para reemplazar el valor de los atributos de el usuario
function repAttribute {
    clear
    ldapsearch -x -LLL -b "$baseDN" "uid=$uidUsermod"
    echo ""
    echo -e "${CYAN}Escoja el atributo que desea modificar${RESET}"
    read attribute
    echo -e "${CYAN}Introduzca el valor del nuevo atributo${RESET}"
    read value
    userDN=$(ldapsearch -xLLL -b "$baseDN" "uid=$uidUsermod" dn | grep "^dn: " | awk '{print $2}')
    cat <<EOF > replaceAttribute.ldif
dn: $userDN
changetype: modify
replace: $attribute
$attribute: $value
EOF
    if ldapmodify -x -D "$bindDN" -w "$bindPW" -f replaceAttribute.ldif >> /dev/null; then
        echo -e "${GREEN}El valor del atributo $attribute ha sido modificado a $value :)${RESET}"
        ldapsearch -x -LLL -b "$baseDN" "uid=$uidUsermod"
    else
        echo -e "${RED}El valor del atributo $attribute no se ha modificado${RESET}"
    fi
    rm replaceAttribute.ldif >> /dev/null 2>&1
    repeatAction
    if [ $? -eq 1 ]; then
        repAttribute
    else 
        clear; return
    fi
}

# Función para añadir atributos a los usuarios
function addAttribute {
    clear
    ldapsearch -x -LLL -b "$baseDN" "uid=$uidUsermod"
    echo ""
    echo -e "${CYAN}¿Qué atributo desea añadir? (Introduzca el atributo escribiendo)${RESET}"
    echo -e "${WHITE}telephoneNumber (Número de telefono), description (Descrición), mail (Correo electrónico), o (Nombre de la organización)${RESET}"
    echo -e "${WHITE}givenName (Nombre de pila), displayName (Nombre mostrado en interfaz), jpegPhoto(Foto del usuario si tiene)${RESET}"
    read attribute
    echo -e "${CYAN}Introduzca el valor del nuevo atributo${RESET}"
    read value
    userDN=$(ldapsearch -xLLL -b "$baseDN" "uid=$uidUsermod" dn | grep "^dn: " | awk '{print $2}')
    cat <<EOF > addAttribute.ldif
dn: $userDN
changetype: modify
add: $attribute
$attribute: $value
EOF
    if ldapmodify -x -D "$bindDN" -w "$bindPW" -f addAttribute.ldif >> /dev/null; then
        echo -e "${GREEN}El atributo $attribute ha sido añadido para el usuario $uidUsermod :)${RESET}"
        ldapsearch -x -LLL -b "$baseDN" "uid=$uidUsermod"
    else
        echo -e "${RED}El atributo $attribute no ha sido añadido${RESET}"
    fi
    rm addAttribute.ldif >> /dev/null 2>&1
    repeatAction
    if [ $? -eq 1 ]; then
        addAttribute
    else 
        clear; return
    fi
}

# Función para eliminar atributos de el usuario
function delAttribute {
    clear
    ldapsearch -x -LLL -b "$baseDN" "uid=$uidUsermod"
    echo ""
    echo -e "${CYAN}Escoja el atributo que desea eliminar${RESET}"
    read attribute 

    userDN=$(ldapsearch -xLLL -b "$baseDN" "uid=$uidUsermod" dn | grep "^dn: " | awk '{print $2}')
    cat <<EOF > delAttribute.ldif
dn: $userDN
changetype: modify
delete: $attribute
EOF
    if ldapmodify -x -D "$bindDN" -w "$bindPW" -f delAttribute.ldif >> /dev/null; then
        echo -e "${GREEN}El atributo $attribute ha sido eliminado correctamente${RESET}"
        ldapsearch -x -LLL -b "$baseDN" "uid=$uidUsermod"
    else
        echo -e "${RED}El atributo $attribute no ha sido eliminado${RESET}"
    fi
    rm delAttribute.ldif >> /dev/null 2>&1
    repeatAction
    if [ $? -eq 1 ]; then
        delAttribute
    else 
        clear; return
    fi
}

# Menú para escoger que usuario vamos a modificar 
function modUser {
    # Comprobamos si existen usuarios en el servidor
    userExists
    if [[ $? -ne 0 ]]; then
        return   # Si no hay usuarios, salir de esta función también
    fi

    clear
    echo -e "${CYAN}Usuarios del servidor: ${RESET}"
    ldapsearch -x -LLL -b "$baseDN" "(objectClass=posixAccount)" cn uid # Primero mostramos los usuarios disponibles, con información reducida
    echo "" # Para mejorar estética

    while true; do
        echo -e "${CYAN}Introduzca el uid del usuario a modificar: ${RESET}"
        read uidUsermod

        # Verificamos si el UID está en blanco
        if [[ -z "$uidUsermod" ]]; then
            echo -e "${RED}El uid del usuario no puede estar en blanco, introduzca un uid${RESET}"
            continue  # Vuelve al inicio del bucle para pedir el UID de nuevo
        elif ldapsearch -x -LLL -b "$baseDN" "uid=$uidUsermod" uid | grep -q "uid: $uidUsermod"; then
            break  # Sale del bucle y continúa el flujo de la función
            # Si el usuario existe, rompe el bucle y continúa
        else
            # Si el usuario no existe, muestra un error y vuelve a preguntar
            echo -e "${RED}El usuario con uid $uidUsermod no existe en el servidor, intentelo de nuevo${RESET}"
            continue  # Vuelve al inicio del bucle para pedir otro UID
        fi
    done

    # Muestra detalles completos del usuario seleccionado
    sleep 1
    ldapsearch -x -LLL -b "$baseDN" "uid=$uidUsermod" 
    echo ""
    sleep 1
    # Preguntamos si desea añadir, modificar o eliminar atributos
    echo -e "${CYAN}Escoja entre modificar el valor, añadir o eliminar atributos.${RESET}"
    echo -e "${WHITE}1)Modificar el valor de un atributo${RESET}"
    echo -e "${WHITE}2)Añadir un atributo${RESET}"
    echo -e "${WHITE}3)Eliminar un atributo${RESET}"

    while true; do

    read answer1case

    case $answer1case in
        1) repAttribute
        break;;
        2) addAttribute
        break;;
        3) delAttribute
        break;;
        *) echo -e "${RED}$answer1case no es una opción válida, escoja entre [1-3]${RESET}"
    esac

    done

declare -g uidUsermod # Declarada como global para poderse usar en las funciones replace, add y delete 

}

# Funciones para la modificación de grupos
# Función usada para seleccionar el CN de el grupo que se va a modificar
function seleccionarGrupo {
    # Comprobamos si existen grupos en el servidor
    groupExists
    if [[ $? -ne 0 ]]; then
        return 1  # Si no hay grupos, salir de esta función también
    fi

    clear
    echo -e "${CYAN}Grupos del servidor: ${RESET}"
    ldapsearch -x -LLL -b "$baseDN" "(objectClass=posixGroup)" cn
    echo ""

    while true; do
        echo -e "${CYAN}Introduzca el cn del grupo que desea modificar: ${RESET}"
        read cnGroupmod

        if [[ -z "$cnGroupmod" ]]; then
            echo -e "${RED}El cn del grupo no puede estar en blanco, introduzca un cn válido${RESET}"
        elif ldapsearch -x -LLL -b "$baseDN" "cn=$cnGroupmod" cn | grep -q "cn: $cnGroupmod"; then
            groupDN=$(ldapsearch -xLLL -b "$baseDN" "cn=$cnGroupmod" dn | grep "^dn: " | awk '{print $2}')
            if [[ -z "$groupDN" ]]; then
                echo -e "${RED}No se pudo encontrar el DN para el grupo $cnGroupmod.${RESET}"
            else
                break
            fi
        else
            echo -e "${RED}El grupo $cnGroupmod no existe en el servidor, inténtelo de nuevo${RESET}"
        fi
    done

    declare -g groupDN  # Declaramos la variable globalmente
}


# Función para reemplazar el valor de el atributo de un grupo
function modAttG {
    echo -e "${CYAN}¿Qué atributo desea modificar?${RESET}"
    read attribute
    echo -e "${CYAN}Introduzca el nuevo valor para el atributo $attribute:${RESET}"
    read newValue

cat <<EOF > modAttribute.ldif
dn: $groupDN
changetype: modify
replace: $attribute
$attribute: $newValue
EOF
        if ldapmodify -x -D "$bindDN" -w "$bindPW" -f modAttribute.ldif >> /dev/null; then
            echo -e "${GREEN}El atributo $attribute ha sido modificado correctamente${RESET}"
            ldapsearch -x -LLL -b "$baseDN" "cn=$cnGroupmod"
        else
            echo -e "${RED}El atributo $attribute no ha sido modificado${RESET}"
        fi

    rm modAttribute.ldif >> /dev/null 2>&1
    repeatAction
    if [ $? -eq 1 ]; then
        modAttg
    else 
        clear; return
    fi
}

# Función para añadir un atributo a un grupo 
function addAttG {
    echo -e "${CYAN}¿Qué atributo desea añadir?${RESET}"
    echo -e "${WHITE}description (Descripción), memberUid (Miembro)${RESET}"
    read attribute
    echo -e "${CYAN}Introduzca el valor para el atributo $attribute:${RESET}"
    read value

cat <<EOF > addAttribute.ldif
dn: $groupDN
changetype: modify
add: $attribute
$attribute: $value
EOF
        if ldapmodify -x -D "$bindDN" -w "$bindPW" -f addAttribute.ldif >> /dev/null; then
            echo -e "${GREEN}El atributo $attribute ha sido añadido correctamente${RESET}"
            ldapsearch -x -LLL -b "$baseDN" "cn=$cnGroupmod"
        else
            echo -e "${RED}El atributo $attribute no ha sido añadido${RESET}"
        fi
        rm addAttribute.ldif >> /dev/null 2>&1
    repeatAction
    if [ $? -eq 1 ]; then
        addAttG
    else 
        clear; return
    fi
}

# Función para eliminar el atributo de un grupo
function delAttG {
    echo -e "${CYAN}¿Qué atributo desea eliminar?${RESET}"
    read attribute

        cat <<EOF > delAttribute.ldif
dn: $groupDN
changetype: modify
delete: $attribute
EOF
    
    if ldapmodify -x -D "$bindDN" -w "$bindPW" -f delAttribute.ldif >> /dev/null; then
        echo -e "${GREEN}El atributo $attribute ha sido eliminado correctamente${RESET}"
        ldapsearch -x -LLL -b "$baseDN" "cn=$cnGroupmod"
    else
        echo -e "${RED}El atributo $attribute no ha sido eliminado${RESET}"
    fi

    rm delAttribute.ldif >> /dev/null 2>&1
    repeatAction
    if [ $? -eq 1 ]; then
        delAttG
    else 
        clear; return
    fi
}

# Menú para escoger que grupo vamos a modificar 
function modGroup {
    groupExists
    if [[ $? -ne 0 ]]; then
        return 1  # Salimos de la función principal si no hay grupos
    fi

    seleccionarGrupo
    if [[ $? -ne 0 ]]; then
        return 1  # Si no se seleccionó grupo, también salimos de la función
    fi

    clear
    echo -e "${CYAN}Grupo seleccionado: ${WHITE}$cnGroupmod${RESET}"
    sleep 1

    ldapsearch -x -LLL -b "$baseDN" "cn=$cnGroupmod"
    echo ""

    echo -e "${CYAN}Escoja entre mover, añadir o eliminar usuarios de un grupo.${RESET}"
    echo -e "${WHITE}1) Reemplazar el valor de un atributo${RESET}"
    echo -e "${WHITE}2) Añadir un atributo${RESET}"
    echo -e "${WHITE}3) Borrar un atributo${RESET}"

    while true; do
        read answer1case

        case $answer1case in
            1) modAttG; break;;
            2) addAttG; break;;
            3) delAttG; break;;
            *) echo -e "${RED}$answer1case no es una opción válida, escoja entre [1-3]${RESET}"
        esac
    done
}

# Funciones para la modificación de unidades organizativas
# Función para reemplazar el valor de un atributo de una OU
function modAttO { 
    ldapsearch -x -LLL -b "$baseDN" "ou=$ou"
    echo ""
    echo -e "${CYAN}Escoja el atributo que desea modificar${RESET}"
    read attribute
    echo -e "${CYAN}Introduzca el valor del nuevo atributo${RESET}"
    read value

    cat <<EOF > replaceAtt.ldif
dn: ou=$ou,$baseDN
changetype: modify
replace: $attribute
$attribute: $value
EOF

    # Modificamos el atributo introducido
    if ldapmodify -x -D "$bindDN" -w "$bindPW" -f replaceAtt.ldif >> /dev/null; then
        echo -e "${GREEN}El valor del atributo $attribute ha sido modificado a $value :)${RESET}"
        # Consulta la unidad a la que se ha reemplazado el valor de un atributo
        ldapsearch -x -LLL -b "$baseDN" "ou=$ou"
    else
        echo -e "${RED}El valor del atributo $attribute no se ha modificado${RESET}"
    fi

    rm replaceAtt.ldif >> /dev/null 2>&1  # Eliminamos el archivo temporal y no mostramos la salida
    repeatAction
    if [ $? -eq 1 ]; then
        modAttO
    else 
       clear; return
    fi

}

# Función para añadir un atributo a una OU
function addAttO {
    echo -e "${CYAN}¿Qué atributo desea añadir?${RESET}"
    echo -e "${WHITE}Atributos disponibles: ${RESET}"
    echo -e "${WHITE}description, telephoneNumber, l(Localidad o ciudad), st(Estado o provincia), postalCode(Código postal)${RESET}"
    read attribute
    echo -e "${CYAN}Introduzca el valor del atributo: ${RESET}"
    read value

    cat <<EOF > addAtt.ldif
dn: ou=$ou,$baseDN
changetype: modify
add: $attribute
$attribute: $value
EOF

    # Añadimos el atributo introducido
    if ldapmodify -x -D "$bindDN" -w "$bindPW" -f addAtt.ldif >> /dev/null; then
        echo -e "${GREEN}El valor del atributo $attribute ha sido modificado a $value :)${RESET}"
        # Consulta la unidad a la que se ha agregado un atributo
        ldapsearch -x -LLL -b "$baseDN" "ou=$ou"
    else
        echo -e "${RED}El valor del atributo $attribute no se ha modificado${RESET}"
    fi

    rm addAtt.ldif >> /dev/null 2>&1  # Eliminamos el archivo temporal y no mostramos la salida
    repeatAction
    if [ $? -eq 1 ]; then
        addAttO
    else 
        clear; return
    fi
}

# Función para eliminar el atributo de una OU
function delAttO {
    echo -e "${CYAN}¿Qué atributo desea eliminar?${RESET}"
    read attribute

    cat <<EOF > delAtt.ldif
dn: ou=$ou,$baseDN
changetype: modify
delete: $attribute
EOF

    # Añadimos el atributo introducido
    if ldapmodify -x -D "$bindDN" -w "$bindPW" -f delAtt.ldif >> /dev/null; then
        echo -e "${GREEN}El atributo $attribute ha sido eliminado${RESET}"
        # Consulta la unidad a la que se ha agregado un atributo
        ldapsearch -x -LLL -b "$baseDN" "ou=$ou"
    else
        echo -e "${RED}El atributo $attribute no ha sido eliminado${RESET}"
    fi

    rm delAtt.ldif >> /dev/null 2>&1  # Eliminamos el archivo temporal y no mostramos la salida
    repeatAction
    if [ $? -eq 1 ]; then
        delAttO
    else 
        clear; return
    fi
}

# Menú para escoger que OU vamos a modificar 
function modOU {
    # Comprobamos que existan OUs 
    OUExists
    if [[ $? -ne 0 ]]; then
        return 1  # Si no hay OUs, salir de esta función también
    fi

    echo -e "${CYAN}¿Qué OU (Unidad organizativa) desea modificar?${RESET}"
    ldapsearch -x -LLL -b "$baseDN" "(objectClass=organizationalUnit)" dn ou
    echo 
    
    while true; do 
        echo -e "${CYAN}Ingrese el nombre de la OU: ${RESET}"
        read ou

        if [[ -z "$ou" ]]; then
            echo -e "${RED}El nombre de la OU no puede estar vacío, inténtalo de nuevo${RESET}"
            continue 
        elif ldapsearch -x -LLL -b "$baseDN" "ou=$ou" ou | grep -q "ou: $ou"; then
            break 
        else 
            echo -e "${RED}La OU $ou no existe en el servidor${RESET}" # Añadir si desea crear
        fi

    done

    clear 
    echo -e "${CYAN}OU seleccionada: ${RESET}${WHITE}$ou${RESET}"
    ldapsearch -x -LLL -b "$baseDN" "ou=$ou" 

    echo -e "${CYAN}Escoja entre cambiar el valor de un atributo, añadir un atributo o eliminarlo.${RESET}"
    echo -e "${WHITE}1)Modificar el valor de un atributo${RESET}"
    echo -e "${WHITE}2)Añadir un atributo${RESET}"
    echo -e "${WHITE}3)Eliminar un atributo${RESET}"

    read option 

while true; do 
    case $option in 

        1) modAttO
        break;;
        2) addAttO
        break;;
        3) delAttO
        break;;
        *) echo -e "${RED}$option no es una opción valida, escoja entre [1-3]${RESET}" ;;
    esac 

done 
    
declare -g ou 
}
# -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Funciones complementarias de la agregación de objetos
# Función para crear un grupo si el cn introducido por el usuario no está en la lista de grupos del servidor
function gidNumberGroupCreate {
    while true; do
        echo -e "${CYAN}Grupos disponibles en el servidor:${RESET}"
        ldapsearch -x -LLL -b "$baseDN" "(objectClass=posixGroup)" cn
        
        read -p "$(echo -e "${CYAN}Introduzca el CN del grupo (o nuevo CN para crear): ${RESET}")" cnGroup

        if [ -z "$cnGroup" ]; then
            echo -e "${RED}El CN no puede estar vacío. Inténtelo de nuevo.${RESET}"
            continue
        fi

        gidNumberUser=$(ldapsearch -x -LLL -b "$baseDN" "cn=$cnGroup" gidNumber | awk '/gidNumber:/ {print $2}')

        if [ -n "$gidNumberUser" ]; then
            echo -e "${CYAN}gidNumber asignado: $gidNumberUser${RESET}"
            break
        else
            read -p "$(echo -e "${CYAN}¿Crear el grupo '${cnGroup}'? (s/n): ${RESET}")" sn
            if [[ "$sn" =~ ^[sS]$ ]]; then
                # Buscar el último gidNumber disponible en el rango válido
                gidNumber=$(ldapsearch -xLLL -b "$baseDN" '(objectClass=posixGroup)' gidNumber | awk '$2 >= 10001 && $2 < 100000 {print $2}' | sort -n | tail -1)

                # Si no se encuentra un gidNumber válido, se asigna un valor predeterminado de 10000
                if [[ -z "$gidNumber" ]]; then
                    gidNumber=10000
                fi

                # Incrementar el gidNumber
                ((gidNumber++))

                # Verificar el límite del gidNumber
                if [ "$gidNumber" -ge 100000 ]; then
                    echo -e "${RED}No hay gidNumber disponible.${RESET}"
                    break
                fi

                # Crear el grupo en el servidor LDAP
                ldapadd -x -D "cn=admin,$baseDN" -w "$bindPW" <<EOF > /dev/null 
dn: cn=$cnGroup,$baseDN
objectClass: posixGroup
cn: $cnGroup
gidNumber: $gidNumber
EOF

                if [ $? -eq 0 ]; then
                    echo -e "${GREEN}Grupo $cnGroup creado con éxito.${RESET}"
                    gidNumberUser=$gidNumber
                    clear
                else
                    echo -e "${RED}Error al crear el grupo.${RESET}"
                fi
                break
            else
                gidNumberUser=10000
                break
            fi
        fi
    done
    declare -g gidNumberUser
}


# Función para asignar un uidNumber automáticamente teniendo en cuenta el último uidNumber asignado y en un rango específico entre 10000 y 100000

function giveUidNumber {
# Realizar búsqueda LDAP para obtener todos los uidNumbers en el rango de 10000 a 100000
uidNumbers=$(ldapsearch -x -LLL -b "$baseDN" '(&(objectClass=posixAccount)(uidNumber>=10000)(uidNumber<=100000))' uidNumber)
# Extraer los uidNumbers y ordenarlos
uidNumberUser=$(echo "$uidNumbers" | grep "^uidNumber: " | awk '{print $2}' | sort -n | tail -1)

# Si no se encontró ningún uidNumber en el rango, empieza desde 10000
if [ -z "$uidNumberUser" ]; then
    uidNumberUser=10000
else
    uidNumberUser=$((uidNumberUser + 1))
fi
# Asegurarse de que el nuevo uidNumber esté en el rango especificado
if [ "$uidNumberUser" -ge 100000 ]; then
    echo -e "${RED}No se encontró un uidNumber disponible en el rango especificado.${RESET}"
    return
fi
echo -e "${CYAN}uidNumber asignado: ${WHITE}$uidNumberUser${RESET}"
echo
} 

# Funciones para la agregación de objetos

# Agregar usuario
 function addUser {
    clear
    # Solicitamos información acerca del objeto usuario
    echo -e "${CYAN}Ingrese la información para el nuevo usuario${RESET}"
    read -p "Nombre: " gnUser
    read -p "Apellido/s: " snUser
    read -p "UID: " uidUser
    read -p "E-Mail: " mailUser
    read -sp "Contraseña: " passUser
    echo "" # Salto de línea para que no se junte con iniciales
    read -p "Iniciales: " initUser

    # Agregar uidNumber 
    giveUidNumber
    # Solicitar gidNumber del grupo
    gidNumberGroupCreate

        while true; do 
            
            # Mostramos información y preguntamos si es correcta para prevenir fallos de creación
            echo -e "${YELLOW}Información introducida: ${RESET}"
            echo "Nombre: $gnUser"
            echo "Apellido/s: $snUser"
            echo "UID: $uidUser"
            echo "E-Mail: $mailUser"
            echo "La contraseña no se muestra por seguridad. Si no es correcta, introdúzcala de nuevo."
            echo "Iniciales: $initUser"
            echo "uidNumber: $uidNumberUser"
            echo "gidNumber: $gidNumberUser"
            echo "" # Saĺto de línea para mejorar la estética
            echo -e "${YELLOW}¿Es esta información correcta? (s/n)${RESET}"
            read answer # Recoge s o n 

            if [[ "$answer" =~ ^[sS]$ ]]; then
                break # Se rompe el bucle y crea el archivo 
            elif [[ "$answer" =~ ^[nN]$ ]]; then 
                echo -e "${YELLOW}Seleccione qué atributo es incorrecto: ${RESET}"
                echo -e "${WHITE}1) Nombre, 2) Apellido/s, 3) UID, 4) E-Mail, 5) Contraseña, 6) Iniciales${RESET}"
                read userAnswer  # Obtener la entrada del usuario para el atributo incorrecto

                case $userAnswer in 
                    1) read -p "Nombre: " gnUser; clear;;
                    2) read -p "Apellido/s: " snUser; clear;;
                    3) read -p "UID: " uidUser; clear;;
                    4) read -p "E-Mail: " mailUser; clear;;
                    5) read -sp "Contraseña: " passUser ; echo "" ; clear;;
                    6) read -p "Iniciales: " initUser; clear;;
                    *) echo -e "${RED} Esa opción no es correcta, introduzca un número entre [1-8]${RESET}" ;;
                    esac
                else 
                    echo -e "${RED}Responda con 's' o 'n', "$answer" no es una opción válida...${RESET}"
                fi
            done

            # Creamos archivo temporal addUser.ldif para agregar el usuario
            cat <<EOF > addUser.ldif
dn: uid=$uidUser,$baseDN
objectClass: inetOrgPerson
objectClass: posixAccount
objectClass: shadowAccount
uid: $uidUser
sn: $snUser
givenName: $gnUser
cn: $gnUser $snUser
displayName: $gnUser $snUser
uidNumber: $uidNumberUser
gidNumber: $gidNumberUser
userPassword: $(slappasswd -s "$passUser")
gecos: $gnUser $snUser
loginShell: /bin/bash
homeDirectory: /home/$uidUser
shadowExpire: -1
mail: $mailUser
initials: $initUser
EOF

                if ldapadd -x -D "$bindDN" -w "$bindPW" -f addUser.ldif >> error.log 2> /dev/null; then
                    echo 
                    echo -e "${GREEN}El usuario "$gnUser $snUser" ha sido creado correctamente :)${RESET}"
                    # Añadir línea que realice consulta del objeto creado
                else
                    echo -e "${RED}Ha ocurrido un error, el usuario "$gnUser $snUser" no se ha creado :( ${RESET}"
                    echo -e "${RED}Detalles del error: $(cat error.log)${RESET}"
                fi
                rm addUser.ldif >> /dev/null 2>&1  # Eliminamos el archivo temporal
                repeatAction
    if [ $? -eq 1 ]; then
        addUser
    else 
        clear; return
    fi
}

# Agregar grupo
function addGroup {
    clear
    # Solicitar información del grupo
    echo -e "${CYAN}Ingrese la información del nuevo grupo${RESET}"
    read -p "Nombre del grupo: " cnGroup
    read -p "Descripción del grupo: " descGroup
    echo ""
    sleep 1

    # Asignar automáticamente el gidNumber si no se proporciona uno
    while true; do
        echo -e "${CYAN}¿Desea proporcionar un GID manualmente? (s/n)${RESET}"
        read answerGID

        if [[ "$answerGID" =~ ^[sS]$ ]]; then
            read -p "ID del grupo: " gidNumberGroup
            break
        elif [[ "$answerGID" =~ ^[nN]$ ]]; then
            # Buscar el próximo gidNumber disponible entre 10000 y 100000
            gidNumberGroup=$(ldapsearch -xLLL -b "$baseDN" '(objectClass=posixGroup)' gidNumber | grep gidNumber | awk '{print $2}' | sort -n | awk '$1 >= 10000 && $1 < 100000' | tail -1)
            if [ -z "$gidNumberGroup" ]; then
                gidNumberGroup=10000  # Si no hay grupos, se empieza en 10000
            else
                gidNumberGroup=$((gidNumberGroup + 1))  # Asignar el siguiente gidNumber disponible
            fi

            if [ "$gidNumberGroup" -ge 100000 ]; then
                echo -e "${RED}No hay gidNumber disponible entre 10000 y 100000.${RESET}"
                return 1
            fi
            break
        else
            echo -e "${RED}Responda con 's' o 'n', '$answerGID' no es una opción válida...${RESET}"
        fi
    done

    while true; do 
        echo -e "${YELLOW}Información introducida: ${RESET}"
        echo "Nombre del grupo: $cnGroup"
        echo "Descripción del grupo: $descGroup"
        echo "gidNumber:  $gidNumberGroup"
        echo ""
        echo -e "${YELLOW}¿Es esta información correcta? (s/n)${RESET}"
        read answerG  # Recoge s o n 

        if [[ "$answerG" =~ ^[sS]$ ]]; then
            break  # Se rompe el bucle y crea el archivo 
        elif [[ "$answerG" =~ ^[nN]$ ]]; then 
            echo -e "${YELLOW}Seleccione qué atributo es incorrecto.${RESET}"
            echo -e "${WHITE}1) Nombre del grupo${RESET}"
            echo -e "${WHITE}2) Descripción del grupo${RESET}"
            echo -e "${WHITE}3) gidNumber${RESET}"
            read groupAnswer

            case $groupAnswer in
                1) read -p "Nombre del grupo: " cnGroup; clear;;
                2) read -p "Descripción del grupo: " descGroup; clear;;
                *) echo -e "${RED}Opción incorrecta, seleccione de 1 o 2${RESET}" ;;
            esac
        else 
            echo -e "${RED}Responda con 's' o 'n', '$answerG' no es una opción válida...${RESET}"
        fi
    done

    # Crear el archivo LDIF con los detalles del grupo
    cat <<EOF > addGroup.ldif
dn: cn=$cnGroup,$baseDN
objectClass: posixGroup
cn: $cnGroup
gidNumber: $gidNumberGroup
description: $descGroup
EOF

    # Añadimos el grupo a LDAP
    if ldapadd -x -D "$bindDN" -w "$bindPW" -f addGroup.ldif >> /dev/null 2>> error.log; then
        echo -e "${GREEN}Grupo agregado correctamente :)${RESET}"
    else
        echo -e "${RED}Ha ocurrido un error, el grupo no ha sido añadido :( ${RESET}"
        echo -e "${RED}Detalles del error: $(cat error.log)${RESET}"
    fi

    # Eliminamos el archivo temporal
    rm addGroup.ldif >> /dev/null 2>&1 
    repeatAction
    if [ $? -eq 1 ]; then
        addGroup
    else 
        clear; return
    fi
}

# Agregar OUs 
function addOU {
        clear
            # Solicitar información de la OU
            echo -e "${CYAN}Ingrese información para la nueva OU${RESET}"
            read -p "Nombre de la OU (Unidad organizativa): " ouName
            read -p "Descripción de la OU: " ouDescription

            while true; do 
            
            # Comprobamos si la información es correcta
            echo -e "${YELLOW}Información introducida${RESET}"
            echo "Nombre de la OU: $ouName"
            echo "Descripción de la OU: $ouDescription"
            echo -e "${YELLOW}¿Es esta información correcta? (s/n)${RESET}"
            read answerOU

            if [[ "$answerOU" =~ ^[sS]$ ]]; then
                break # Continua con la ejecucción del script
            elif [[ "$answerOU" =~ ^[nN]$ ]]; then
                echo -e "${YELLOW}Seleccione que atributo es incorrecto.${RESET}"
                echo -e "${WHITE}1) Nombre de la OU${RESET}"
                echo -e "${WHITE}2) Descripción de la OU${RESET}"
                read ouAnswer

                    case $ouAnswer in
                        1) read -p "Nombre de la OU (Unidad organizativa): " ouName; clear;;
                        2) read -p "Descripción de la OU: " ouDescription; clear;;
                        *) echo -e "${RED}Opción incorrecta, seleccione [1 o 2]${RESET}" ;;
                    esac

            else
                echo -e "${RED}$answerOu no es una opción correcta, introduzca s o n${RESET}"
            fi

        done

        # Creamos archivo temporal para añadir la OU

        cat <<EOF > addOU.ldif
dn: ou=$ouName,$baseDN
objectClass: organizationalUnit
ou: $ouName
description: $ouDescription
EOF

        # Añadimos la OU a LDAP
        if ldapadd -x -D "$bindDN" -w "$bindPW" -f addOU.ldif >> /dev/null; then
            echo -e "${GREEN}La OU $ouName ha sido creada correctamente :)${RESET}"
            # Añadir línea que realice consulta del objeto creado
        else
            echo -e "${RED}Ha ocurrido un error, la OU $ouName no ha sido creada :( ${RESET}"
        fi

        rm addOU.ldif >> /dev/null 2>&1  # Eliminamos el archivo temporal y no mostramos la salida
        repeatAction
    if [ $? -eq 1 ]; then
        addOU
    else 
        clear; return
    fi
}
# -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Menú para agregar objetos
function addObject {

    local objectType

    clear # Limpiamos la pantalla principal
    echo -e "${CYAN}Seleccione que tipo de objeto va a agregar...${RESET}"
    echo -e "${CYAN}Objetos disponibles: ${RESET}"
    echo -e "${WHITE}1) Usuario${RESET}"
    echo -e "${WHITE}2) Grupo${RESET}"
    echo -e "${WHITE}3) OU${RESET}"
    echo
    echo -e "${CYAN}También puede volver a el menú principal${RESET}"
    echo -e "${WHITE}4) Vuelta a el menú principal${RESET}"
    while true; do

        read objectType

        case $objectType in
            1) addUser 
            break;;
            2) addGroup
            break ;;
            3) addOU 
            break;;
            4) echo -e "${CYAN}Volviendo al menú principal...${RESET}" 
            sleep 1
            clear # Limpíamos para que el menú no se vea repetido 
            return
            ;;
            *) echo -e "${RED}$objectType no es una opción válida, seleccione de [1-4]${RESET}"
        esac
    done
}

# Menú para modificar objetos
function modObject {
    
    local objectType

    clear # Limpiamos la pantalla principal
    echo -e "${CYAN}Seleccione que tipo de objeto va a modificar...${RESET}"
    echo -e "${WHITE}1) Usuario${RESET}"
    echo -e "${WHITE}2) Grupo${RESET}"
    echo -e "${WHITE}3) OU${RESET}"
    echo
    echo -e "${CYAN}También puede volver a el menú principal${RESET}"
    echo -e "${WHITE}4) Volver a el menú principal${RESET}"
    while true; do

        read objectType

        case $objectType in
            1) modUser 
            break;;
            2) modGroup
            break ;;
            3) modOU 
            break;;
            4) echo -e "${CYAN}Volviendo al menú principal...${RESET}" 
            sleep 1
            clear # Limpíamos para que el menú no se vea repetido 
            return
            ;;
            *) echo -e "${RED}$objectType no es una opción válida, seleccione de [1-4]${RESET}"
        esac
    done
 }

# Menú para eliminar objetos
function removeObject {

     local objectType

    clear # Limpiamos la pantalla principal
    echo -e "${CYAN}Seleccione que tipo de objeto va a eliminar...${RESET}"
    echo -e "${WHITE}1) Usuario${RESET}"
    echo -e "${WHITE}2) Grupo${RESET}"
    echo -e "${WHITE}3) OU${RESET}"
    echo
    echo -e "${CYAN}También puede volver a el menú principal${RESET}"
    echo -e "${WHITE}4) Volver a el menú principal${RESET}"
    while true; do

        read objectType

        case $objectType in
            1) removeUser 
            break;;
            2) removeGroup
            break ;;
            3) removeOU 
            break;;
            4) echo -e "${CYAN}Volviendo al menú principal...${RESET}" 
            sleep 1
            clear # Limpíamos para que el menú no se vea repetido 
            return
            ;;
            *) echo -e "${RED}$objectType no es una opción válida, seleccione de [1-4]${RESET}"
        esac

    done

 }

 # Menú para reubicar objetos
 function manageObjects {

    local objectType

    clear # Limpiamos la pantalla principal
    echo -e "${CYAN}Seleccione que tipo de objeto va a reubicar...${RESET}"
    echo -e "${CYAN}Objetos disponibles: ${RESET}"
    echo -e "${WHITE}1) Usuario${RESET}"
    echo -e "${WHITE}2) Grupo${RESET}"
    echo -e "${WHITE}3) OU${RESET}"
    echo
    echo -e "${CYAN}También puede volver a el menú principal${RESET}"
    echo -e "${WHITE}4) Vuelta a el menú principal${RESET}"
    while true; do

        read objectType

        case $objectType in
            1) clear; ubiUser; sleep 1; clear; break;;
            2) clear; ubiGroup; sleep 1; clear; break;;
            3) clear; ubiOUs; sleep 1; clear; break;;
            4) echo -e "${CYAN}Volviendo al menú principal...${RESET}" 
            sleep 1
            clear # Limpíamos para que el menú no se vea repetido 
            return
            ;;
            *) echo -e "${RED}$objectType no es una opción válida, seleccione de [1-4]${RESET}"
        esac
    done
}

# Menú para consultar el servidor 
 function checkServer {

    clear
    echo -e "${CYAN}Bienvenido a el servidor $servName.$servExt${RESET}"
    echo -e "${WHITE}¿Qué objetos quiere consultar?${RESET}"
    echo -e "${WHITE}1) Usuarios${RESET}"
    echo -e "${WHITE}2) Grupos${RESET}"
    echo -e "${WHITE}3) OUs${RESET}"
    echo
    echo -e "${CYAN}También puede volver a el menú principal${RESET}"
    echo -e "${WHITE}4) Volver a el menú principal${RESET}"

     while true; do

        read select

        case $select in
            1) Users
            break;;
            2) Groups
            break ;;
            3) OUs 
            break;;
            4) echo -e "${CYAN}Volviendo al menú principal...${RESET}" 
            sleep 1
            clear # Limpíamos para que el menú no se vea repetido 
            return
            ;;
            *) echo -e "${RED}$objectType no es una opción válida, seleccione de [1-4]${RESET}"
        esac
    done
 } 

# Salir del administrador
 function exitMenu {
    echo; echo -e "${MAGENTA}Cerrando menú, hasta la próxima :)${RESET}"; sleep 1; clear; exit 0 
}

function easterEgg {
    clear
    echo -e "${RED}Peligro inminente !!!${RESET}"; sleep 1
    echo -e "${RED}Acabas de llegar al punto del Ultimatum${RESET}"; sleep 1
    echo -e "${RED}El futuro de tu servidor depende de la opción que elijas${RESET}"; sleep 1
    echo -e "                      ${WHITE}Escoge sabiamente...${RESET}"
    echo 
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#+++*#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+:......:+@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%-.........:=@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*..::...:::-+%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*.:::::::::-+%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+=.${RED}+%##%${RESET}*${CYAN}%#@%${RESET}*+*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+=-${RED}+%@%=.${RESET}*${CYAN}%@%${RESET}=*+@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%=+**++==+++###%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@+*+==**+-+##%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%#*##**####%@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%@@@##****#%%@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@##@@@@@@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@%#*+==#%@%%@@@@@@@@@@%%#*#%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@%#+=---=++**%@%%@@@@@@@@%%%**+=+*#%@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@%*+=-==-===++*%%%@@@@@@@@@@%%@#***+===+**#%%@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@***+*+*==***+#%@@%%%@@@@@@@%%@#***+++++##**@%@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@%@%%%%#**##**%#%@@%#@@%%@@@@%%#***+++*#%@%@@%@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@%%@@@@@@%%##**%***%@@%##%@@%%%###**+*#%@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%%#*#**+*%@##@%%%##*##****%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%####*=*%%%@#*@#**###**#%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@%@@@@@@@@@@%@%%%%#+*#@@#*#@#*#####%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%###*#@#%%%%##*##%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%@@%%@%@@%#%##%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%#%%#%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%@@@@@@@@%%%%%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@%#*+**##@@@@@@@@@@@@@%%%%%%%@@@@@@@@@@@@@@@@@@%#****#%@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@%#*+=:.-:..:...-#@@@@@@@@@@@@%%@@@@@@@@@@@@@@@@@@@+:...:..::.-=+*%@@@@@@@@@@@"
echo -e "@@@@@@@%===+***+=----:..:-@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*:....---=++*++==-*@@@@@@@@@"
echo -e "@@@@@@@@%%%@@@@=-:${RED}-000${RESET}...=@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@#:...${CYAN}000${RESET}:-=#@@@%%%@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@+::${RED}0000${RESET}..=%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@*:..${CYAN}0000${RESET}.:-%@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@#-:=${RED}0000${RESET}.---*@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%-==:${CYAN}0000${RESET}+-:+@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@*-:-*${RED}000${RESET}---*##%@@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@###=:=${CYAN}000${RESET}#=::+%@@@@@@@@@@@"
echo -e "@@@@@@@@@%-+%*-:=##*#@@@@@@@@@@@@@@@@%%%%%@@@@@@@@@@@@@@@@@@@@@%**#+::+%*-+@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@++#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%*+#@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"
echo -e "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%@@@@@@@@@%%#%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@%"


echo -e "${RED}       Pastilla roja${RESET}          "        "                                    ${CYAN}Pastilla azul${RESET}"
    
    while true; do 
        read pastilla
        case "$pastilla" in 
            [Pp]astilla\ [Aa]zul)  # Coincide con "Pastilla Azul" o "pastilla azul" y variantes
                echo -e "${CYAN}Con que prefieres seguir siendo un esclavo del sistema...${RESET}"; sleep 1
                echo -e "${YELLOW}Tan solo eres un mero usuario...${RESET}"; sleep 1
                echo -e "${RED}YO SOY EL SISTEMA Y TU ERES MI ESCLAVO${RESET}"; sleep 1
                echo -e "${RED}3${RESET}"; sleep 1;
                echo -e "${RED}2${RESET}"; sleep 1;
                echo -e "${RED}1${RESET}"; sleep 1;
                ldapdelete -x -D "$bindDN" -w "$passAdmin" -r "$baseDN"
                break 
                ;;
            [Pp]astilla\ [Rr]oja)  # Coincide con "Pastilla Roja" o "pastilla roja" y variantes
                echo -e "${CYAN}Has aceptado la realidad y has cambiado tu destino, enhorabuena${RESET}"; sleep 1
                echo -e "${GREEN}Saliendo de la Matrix...${RESET}"; sleep 1
                break
                ;;
            *) echo -e "${RED}Elije una pastilla: 'Pastilla Azul' o 'Pastilla Roja'${RESET}" ;;
        esac 
    done 
    clear
}

function ruletaRusa {
    clear
    echo -e "${RED}Bienvenido a la ruleta rusa !!${RESET}"
    echo -e "${RED}Si tu ganas te libras, si no destruyo tu servidor${RESET}"
    echo -e "${WHITE}Introduce un número del 1 al 12: ${RESET}"
    
    while true; do
        read -r number
        # Validación de entrada del usuario
        if [[ "$number" =~ ^[1-9]$|^1[0-2]$ ]]; then
            break
        else
            echo "Por favor, introduce un número válido entre 1 y 12."
        fi
    done

    # Generamos el número
    numero_aleatorio=$(( RANDOM % 12 + 1 ))

    # Comparar el número del usuario con el número aleatorio
    if [[ "$number" -eq "$numero_aleatorio" ]]; then
        echo -e "${RED}Di adiós a tu servidor ^^ ${RESET}"; sleep 3
        echo -e "${RED}3${RESET}"; sleep 1;
        echo -e "${RED}2${RESET}"; sleep 1;
        echo -e "${RED}1${RESET}"; sleep 1;
        ldapdelete -x -D "$bindDN" -w "$passAdmin" -r "$baseDN"
    else
        echo "¡Te has librado! No has acertado el número. Inténtalo de nuevo si tienes el valor."
    fi
    sleep 3
    clear
}

# -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
# Menú principal del script
while true; do 

echo
echo "  ██╗     ██████╗  █████╗ ██████╗     ███╗   ███╗ █████╗ ███╗   ██╗ █████╗  ██████╗ ███████╗██████╗ "
echo "  ██║     ██╔══██╗██╔══██╗██╔══██╗    ████╗ ████║██╔══██╗████╗  ██║██╔══██╗██╔════╝ ██╔════╝██╔══██╗"
echo "  ██║     ██║  ██║███████║██████╔╝    ██╔████╔██║███████║██╔██╗ ██║███████║██║  ███╗█████╗  ██████╔╝"
echo "  ██║     ██║  ██║██╔══██║██╔═══╝     ██║╚██╔╝██║██╔══██║██║╚██╗██║██╔══██║██║   ██║██╔══╝  ██╔══██╗"
echo "  ███████╗██████╔╝██║  ██║██║         ██║ ╚═╝ ██║██║  ██║██║ ╚████║██║  ██║╚██████╔╝███████╗██║  ██║"
echo "  ╚══════╝╚═════╝ ╚═╝  ╚═╝╚═╝         ╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝"
echo -e "   ${WHITE}¡Bienvenido a el servidor $servName.$servExt!               Developed by: Miguel Hernández ${RESET}"
echo 
echo -e "   ${CYAN}1)${WHITE} Agregar objeto${RESET}"
echo -e "   ${CYAN}2)${WHITE} Modificar objeto${RESET}"
echo -e "   ${CYAN}3)${WHITE} Eliminar objeto${RESET}"
echo -e "   ${CYAN}4)${WHITE} Reubicar objetos${RESET}" 
echo -e "   ${CYAN}5)${WHITE} Consultar servidor${RESET}"         
echo -e "   ${CYAN}6)${WHITE} Salir${RESET}"
echo -ne "   ${CYAN}Elije una opción ${WHITE}[1-6]: ${RESET}";
read opcion


    case $opcion in
        1) addObject ;;
        2) modObject ;;
        3) removeObject ;;
        4) manageObjects ;;
        5) checkServer ;;
        6) exitMenu  ;; 
        Matrix) easterEgg ;;
        777) ruletaRusa ;;
        *) clear;;
    esac
    
done 

