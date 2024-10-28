#!/bin/bash

# Comprobar si el usuario puede usar sudo y pedir la contraseña
if sudo -v; then
    echo "¡Bienvenido, $USER! Tienes privilegios de sudo."
else
    echo "Este script debe ser ejecutado con privilegios de sudo."
    exit 1
fi

# Aquí puedes incluir más lógica para el script
echo "Continuando con el script..."