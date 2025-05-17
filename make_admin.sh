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
    docker-compose up -d
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Error al iniciar el contenedor. Verifique los logs para más detalles.${NC}"
        exit 1
    fi
    echo -e "${GREEN}✅ Contenedor iniciado correctamente.${NC}"
    echo -e "${YELLOW}⏳ Esperando 5 segundos para que la aplicación esté lista...${NC}"
    sleep 5
else
    echo -e "${GREEN}✅ El contenedor ya está en ejecución.${NC}"
fi

echo -e "${YELLOW}🔧 Creando script de actualización dentro del contenedor...${NC}"

# Crear un script temporal para actualizar usuario a administrador
cat > update_admin.py << 'EOL'
from app import app, db, User

def make_user_admin(email):
    with app.app_context():
        user = User.query.filter_by(email=email).first()
        if not user:
            print(f"❌ No se encontró ningún usuario con el correo {email}")
            return False
            
        # Verificar si existe la columna is_admin
        try:
            existing_admin = user.is_admin
        except AttributeError:
            # La columna no existe, intentar añadirla
            print("ℹ️ La columna is_admin no existe, actualizando la estructura de la base de datos...")
            try:
                import sqlite3
                import os
                
                db_path = os.path.join('instance', 'dmarcdefense.db')
                conn = sqlite3.connect(db_path)
                cursor = conn.cursor()
                
                # Verificar si la columna ya existe
                cursor.execute("PRAGMA table_info(user)")
                columns = cursor.fetchall()
                column_names = [column[1] for column in columns]
                
                if 'is_admin' not in column_names:
                    cursor.execute("ALTER TABLE user ADD COLUMN is_admin BOOLEAN DEFAULT 0")
                    conn.commit()
                    print("✅ Columna is_admin añadida a la tabla user")
                
                conn.close()
                
                # Recargar el modelo de usuario
                db.create_all()
                
                # Obtener el usuario nuevamente
                user = User.query.filter_by(email=email).first()
            except Exception as e:
                print(f"❌ Error al actualizar la estructura de la base de datos: {e}")
                return False
        
        # Hacer administrador al usuario
        user.is_admin = True
        try:
            db.session.commit()
            print(f"✅ Usuario {email} actualizado con éxito a administrador")
            return True
        except Exception as e:
            db.session.rollback()
            print(f"❌ Error al actualizar el usuario: {e}")
            return False

if __name__ == "__main__":
    import sys
    if len(sys.argv) < 2:
        print("❌ Por favor, proporcione el correo electrónico del usuario a convertir en administrador")
        print("Uso: python update_admin.py correo@ejemplo.com")
        sys.exit(1)
        
    email = sys.argv[1]
    if make_user_admin(email):
        print(f"✅ Usuario {email} ahora es administrador")
        sys.exit(0)
    else:
        print(f"❌ No se pudo convertir a {email} en administrador")
        sys.exit(1)
EOL

echo -e "${YELLOW}🔄 Copiando script al contenedor...${NC}"
docker cp update_admin.py dmarcdefensespoofingtool-dmarcdefense-app-1:/app/

# Solicitar correo electrónico
read -p "Ingrese el correo electrónico del usuario que desea convertir en administrador: " EMAIL

echo -e "${YELLOW}🔧 Convirtiendo ${EMAIL} en administrador...${NC}"
docker exec dmarcdefensespoofingtool-dmarcdefense-app-1 python /app/update_admin.py "$EMAIL"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Proceso completado. El usuario $EMAIL ahora es administrador.${NC}"
    echo -e "${GREEN}   Reinicie la aplicación para que los cambios surtan efecto.${NC}"
    
    # Preguntar si desea reiniciar
    read -p "¿Desea reiniciar la aplicación ahora? (s/n): " RESTART
    if [[ $RESTART =~ ^[Ss]$ ]]; then
        echo -e "${YELLOW}🔄 Reiniciando la aplicación...${NC}"
        docker restart dmarcdefensespoofingtool-dmarcdefense-app-1
        echo -e "${GREEN}✅ Aplicación reiniciada correctamente.${NC}"
    else
        echo -e "${YELLOW}ℹ️ No se reinició la aplicación. Recuerde reiniciarla manualmente para aplicar los cambios.${NC}"
    fi
else
    echo -e "${RED}❌ Hubo un problema al convertir al usuario en administrador.${NC}"
fi

# Limpieza
rm update_admin.py
