#!/bin/bash

#Configuracion de variables
read -p "Introduce el dominio: " dominio
read -p "Introduce el usuario root de LDAP: " BIND_DN_ROOT
read -p "IP del servidor ldap: " IP_LDAP

LDAP_CONF="/etc/ldap/ldap.conf"
NSS_CONF="/etc/nsswitch.conf"
LDAP_CONF2="/etc/ldap.conf"

cat >> /etc/hosts <<EOL
$IP_LDAP    ldap.$dominio
EOL

#Instalacion paquetes cliente ldap
sudo DEBIAN_FRONTEND=noninteractive  apt install libnss-ldap libpam-ldap ldap-utils -y

# Divide el dominio en partes utilizando el punto como delimitador
IFS='.' read -r -a partes <<< "$dominio"

# Inicializa la variable LDAP
ldap_format=""

# Recorre las partes y las transforma al formato LDAP
for parte in "${partes[@]}"; do
    ldap_format+="dc=${parte},"
done

# Elimina la última coma
ldap_format="${ldap_format%,}"

#Editamos el fichero /etc/ldap/ldap.conf
sed -i "s/BASE.*/BASE\t$ldap_format/" $LDAP_CONF
sed -i "s/URI.*/URI\tldap:\/\/ldap.$dominio/" $LDAP_CONF

# editamos el fichero /etc/ldap.conf
sed -i "s/base.*/base $ldap_format/" $LDAP_CONF2
sed -i "s/uri.*/uri ldap:\/\/ldap.$dominio/" $LDAP_CONF2
sed -i "s/rootbinddn.*/rootbinddn cn=$BIND_DN_ROOT,$ldap_format/" $LDAP_CONF2


#Modificamos el fichero "/etc/nsswitch.conf"
sed -i '/^passwd:/s/$/ ldap/' $NSS_CONF
sed -i '/^group:/s/$/ ldap/' $NSS_CONF
sed -i '/^shadow:/s/$/ ldap/' $NSS_CONF

#Añadimos la linea necesaria al fichero common-session
echo "session    optional    pam_mkhomedir.so    skel=/etc/skel   umask=077" >> /etc/pam.d/common-session