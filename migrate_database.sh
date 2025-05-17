#!/bin/bash

# Colores para salida
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔍 Verificando estado del contenedor...${NC}"
CONTAINER_STATUS=$(docker inspect --format='{{.State.Status}}' dmarcdefensespoofingtool-dmarcdefense-app-1 2>/dev/null)

if [ $? -ne 0 ] || [ "$CONTAINER_STATUS" != "running" ]; then
    echo -e "${RED}❌ El contenedor no está en ejecución. Iniciando contenedor...${NC}"
    
    # Si no está ejecutándose, iniciarlo primero
    docker-compose up -d
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error al iniciar el contenedor. Verifique los logs para más detalles.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Contenedor iniciado correctamente.${NC}"
else
    echo -e "${GREEN}✅ El contenedor ya está en ejecución.${NC}"
fi

echo -e "${YELLOW}⏳ Esperando 5 segundos para que la aplicación esté lista...${NC}"
sleep 5

echo -e "${YELLOW}🔧 Migrando la base de datos...${NC}"
docker exec dmarcdefensespoofingtool-dmarcdefense-app-1 python migrate_database.py

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Migración completada exitosamente.${NC}"
else
    echo -e "${RED}❌ Error en la migración. Verifique los logs para más detalles.${NC}"
    docker logs dmarcdefensespoofingtool-dmarcdefense-app-1 | tail -50
    exit 1
fi

echo -e "${YELLOW}🔄 Reiniciando el contenedor para aplicar los cambios...${NC}"
docker-compose restart

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Contenedor reiniciado correctamente.${NC}"
    echo -e "${GREEN}   La aplicación ahora debería funcionar con la estructura actualizada de la base de datos.${NC}"
else
    echo -e "${RED}❌ Error al reiniciar el contenedor.${NC}"
    exit 1
fi
