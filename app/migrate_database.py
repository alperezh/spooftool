from app import app, db, SentEmail, User
import sqlite3
import os

def migrate_database():
    # Ruta a la base de datos SQLite
    db_path = os.path.join('instance', 'dmarcdefense.db')
    
    if not os.path.exists(db_path):
        print("❌ Base de datos no encontrada en:", db_path)
        return False
    
    print(f"✅ Base de datos encontrada en: {db_path}")
    
    try:
        # Conectar a la base de datos SQLite directamente
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Verificar si las columnas ya existen
        cursor.execute("PRAGMA table_info(sent_email)")
        columns = cursor.fetchall()
        column_names = [column[1] for column in columns]
        
        print("ℹ️ Columnas actuales:", column_names)
        
        # Añadir columna user_email si no existe
        if 'user_email' not in column_names:
            print("ℹ️ Añadiendo columna user_email...")
            cursor.execute("ALTER TABLE sent_email ADD COLUMN user_email TEXT")
            
            # Actualizar user_email con el correo del usuario basado en user_id
            cursor.execute("""
                UPDATE sent_email 
                SET user_email = (
                    SELECT email FROM user WHERE user.id = sent_email.user_id
                )
            """)
            print("✅ Columna user_email añadida y actualizada")
        else:
            print("ℹ️ La columna user_email ya existe")
        
        # Añadir columna template_id si no existe
        if 'template_id' not in column_names:
            print("ℹ️ Añadiendo columna template_id...")
            cursor.execute("ALTER TABLE sent_email ADD COLUMN template_id TEXT DEFAULT 'custom'")
            print("✅ Columna template_id añadida")
        else:
            print("ℹ️ La columna template_id ya existe")
        
        # Confirmar cambios y cerrar la conexión
        conn.commit()
        conn.close()
        
        print("✅ Migración completada exitosamente")
        return True
        
    except Exception as e:
        print(f"❌ Error durante la migración: {str(e)}")
        return False

if __name__ == "__main__":
    with app.app_context():
        # Asegurarse de que todas las tablas existen
        print("ℹ️ Verificando tablas existentes...")
        db.create_all()
        
        # Ejecutar la migración
        print("ℹ️ Iniciando migración...")
        success = migrate_database()
        
        # Verificar el resultado
        if success:
            print("🎉 Base de datos actualizada correctamente")
        else:
            print("⚠️ No se pudo completar la migración")
