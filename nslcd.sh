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
