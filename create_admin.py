from app import app, db, User
from werkzeug.security import generate_password_hash

# Ejecutar dentro del contexto de la aplicación
with app.app_context():
    # Verificar si el admin ya existe
    admin_exists = User.query.filter_by(email='admin@dmarcdefense.com').first()
    
    if not admin_exists:
        # Crear usuario administrador
        admin = User(
            email='aperez@dmarcdefense.com',
            name='Administrador',
            company='DMARCDefense',
            password_hash=generate_password_hash('162214Sandra*')
        )
        
        # Guardar en la base de datos
        db.session.add(admin)
        db.session.commit()
        
        print("✅ Usuario administrador creado con éxito.")
        print("   Email: aperez@dmarcdefense.com")
        print("   Hint Contraseña: Sandrita")
    else:
        print("⚠️ El usuario administrador ya existe.")
