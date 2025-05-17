import os
from getpass import getpass
from app import app, db, User
from werkzeug.security import generate_password_hash


def create_admin_user(email, name, company, password):
    with app.app_context():
        existing_user = User.query.filter_by(email=email).first()
        if existing_user:
            print(f"⚠️ El usuario administrador ya existe: {email}")
            return

        hashed_password = generate_password_hash(password)
        admin = User(
            email=email,
            name=name,
            company=company,
            password_hash=hashed_password
        )
        db.session.add(admin)
        db.session.commit()

        print(f"✅ Usuario administrador creado con éxito.")
        print(f"   Email: {email}")


if __name__ == "__main__":
    # Recomendado: usar variables de entorno o entrada segura
    email = os.getenv("ADMIN_EMAIL") or input("Correo del admin: ")
    name = "Administrador"
    company = "DMARCDefense"
    password = os.getenv("ADMIN_PASSWORD") or getpass("Contraseña segura para admin: ")

    create_admin_user(email, name, company, password)
