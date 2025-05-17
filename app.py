from flask import Flask, render_template, request, redirect, url_for, flash, session
import requests
import base64
import os
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash
from email_validator import validate_email, EmailNotValidError

app = Flask(__name__)
app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY')
if not app.config['SECRET_KEY']:
    app.config['SECRET_KEY'] = 'clave_temporal_solo_desarrollo'
    print("⚠️ ADVERTENCIA: SECRET_KEY no configurada. Usando clave temporal solo para desarrollo.")

app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///dmarcdefense.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)
login_manager = LoginManager(app)
login_manager.login_view = 'login'

# Obtener credenciales de API desde variables de entorno
API_URL = os.environ.get('API_URL')
API_TOKEN = os.environ.get('API_TOKEN')

# Verificar que las credenciales de API están configuradas
if not API_URL or not API_TOKEN:
    print("⚠️ ERROR: Variables de entorno API_URL y API_TOKEN son requeridas.")
    print("📝 Por favor, configura estas variables como se describe en README.md")
    # En producción, podrías querer que esto falle rápidamente
    # Pero para desarrollo, permitimos valores temporales
    if not API_URL:
        print("🔄 Usando URL de API temporal para desarrollo")
        API_URL = 'http://localhost:5000/dummy_endpoint'
    if not API_TOKEN:
        print("🔄 Usando token de API temporal para desarrollo")
        API_TOKEN = 'dummy_token_solo_desarrollo'

# Modelos de la base de datos
class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    email = db.Column(db.String(120), unique=True, nullable=False)
    password_hash = db.Column(db.String(128))
    name = db.Column(db.String(100))
    company = db.Column(db.String(100))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    emails = db.relationship('SentEmail', backref='user', lazy=True)

    def set_password(self, password):
        self.password_hash = generate_password_hash(password)
        
    def check_password(self, password):
        return check_password_hash(self.password_hash, password)

class SentEmail(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    user_email = db.Column(db.String(120), nullable=True)  # Puede ser nulo para compatibilidad
    sender = db.Column(db.String(120), nullable=False)
    recipient = db.Column(db.String(200), nullable=False)
    subject = db.Column(db.String(200), nullable=False)
    body = db.Column(db.Text, nullable=False)
    template_id = db.Column(db.String(10), nullable=True)  # Puede ser nulo para compatibilidad
    status = db.Column(db.String(20), default='sent')
    sent_at = db.Column(db.DateTime, default=datetime.utcnow)

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# Plantillas predefinidas
TEMPLATES = {
    '1': """Asunto: Prueba de concepto de suplantación de dominio ***Company***

Prueba de concepto de suplantación de dominio por https://dmarcdefense.com
Basándonos en nuestras pruebas, utilizando únicamente información pública disponible en servidores DNS, hemos determinado que el dominio ***Dominio*** puede suplantarse fácilmente para enviar correos electrónicos fraudulentos en su nombre.

Para obtener más información sobre cómo realizamos esta prueba y cómo puede mitigar esta vulnerabilidad, no dude en contactarnos en info@dmarcdefense.com.

Gracias por su confianza.""",

    '2': """Asunto: Acción inmediata requerida: verifique su cuenta bancaria en línea ***Company***

Estimado cliente:

Notamos una actividad inusual en su cuenta bancaria en línea y, como medida de precaución, necesitamos confirmar las credenciales de su cuenta para garantizar que su cuenta permanezca segura.

Para su conveniencia, le proporcionamos un enlace seguro para verificar su información. Complete el proceso de verificación dentro de las 24 horas para evitar interrupciones en sus servicios bancarios.

Haga clic aquí para verificar su cuenta: http://linkspearphishing.com

Si no recibimos su confirmación dentro del plazo especificado, su acceso a la banca en línea puede suspenderse temporalmente. Si tiene alguna pregunta, responda a este correo electrónico y nuestro equipo de soporte lo ayudará.

Gracias por su pronta atención a este asunto.

Atentamente,
Equipo de atención al cliente
***Company***
Sitio web: www.fakeurl.com""",

    '3': """Asunto: Urgente: Instrucciones de pago actualizadas para la factura [Factura #123456] ***Company***

Estimado cliente:

Espero que este mensaje le llegue bien. Nos comunicamos con usted en relación con la factura pendiente n.° [Factura n.° 123456] por el monto de $5,345, que está próxima a vencerse.

Tenga en cuenta que recientemente hemos actualizado nuestros datos bancarios. Para garantizar el procesamiento rápido de su pago, utilice la siguiente información actualizada:

Nuevos datos bancarios:
Nombre de la cuenta: Actor Malicioso
Nombre del banco: Banco del Actor Malicioso
Número de cuenta: 123456789
Código de clasificación: 00-11-22

Actualice estos datos en sus registros y procese el pago lo antes posible. Para evitar demoras o sanciones, le solicitamos que el pago se realice a la brevedad.

Si ya realizó el pago a nuestra cuenta anterior, notifíquenos de inmediato para que podamos ayudarlo a resolver el problema. Si tiene alguna pregunta, no dude en responder a este correo electrónico o contáctenos directamente al 1-800-HACKERS.

Gracias por su atención a este asunto.

Atentamente,
***Nombre***
Departamento de facturación
***Company***
Teléfono: 1-800-HACKERS
Correo electrónico: billing@LOOKALIKEdomain.com""",

    '4': """Asunto: Todos los empleados ***Company***

Estimado equipo:

Como parte de nuestros esfuerzos constantes por mantener la seguridad e integridad de nuestros sistemas financieros, es fundamental que realicemos una verificación exhaustiva de todas las cuentas asociadas a los empleados de inmediato.

Debido a las actualizaciones recientes de nuestros requisitos de cumplimiento, le solicito que proporcione una confirmación rápida de los detalles de su cuenta mediante el portal seguro vinculado a continuación. Asegúrese de que esto se complete antes del cierre de operaciones de hoy.

Haga clic aquí para acceder al portal de verificación: http://linkspearphishing.com

Si no completa este proceso, es posible que se restrinja temporalmente el acceso a sus privilegios bancarios de empleado. Si tiene algún problema, responda directamente a este correo electrónico y nuestro equipo de seguridad informática lo ayudará de inmediato.

Gracias por su rápida cooperación.

Un cordial saludo,
**Nombre**
**Cargo**
**Company**""",

    '5': """Asunto: ¡Actualiza tus datos con ***Company*** y mantente conectado con nosotros!

Estimado Cliente,

En ***Company***, queremos asegurarnos de que siempre recibas la mejor atención y los beneficios exclusivos que tenemos para ti. Por eso, te invitamos a actualizar tus datos en nuestra página web.

Mantener tu información actualizada nos permite:
- Ofrecerte un servicio más personalizado.
- Informarte sobre promociones y novedades relevantes.
- Garantizar que recibas nuestras notificaciones importantes.

Actualizar tus datos es muy fácil y rápido. Solo sigue estos pasos:
1. Ingresa a nuestra página web: http://linkspearphishing.com
2. Inicia sesión con tu cuenta.

Revisa y actualiza tu información en pocos minutos.

Si tienes alguna duda o necesitas ayuda, nuestro equipo de atención al cliente estará encantado de asistirte en [Correo o Teléfono de Contacto].

¡Gracias por ser parte de ***Company***!

Atentamente,
***Nombre***
Departamento de atención al cliente
***Company***
Teléfono: 1-800-HACKERS
Correo electrónico: billing@LOOKALIKEdomain.com"""
}

# Inicializar la base de datos
with app.app_context():
    db.create_all()

# Verificar y añadir columnas nuevas si no existen
def migrate_database():
    try:
        db_path = os.path.join('instance', 'dmarcdefense.db')
        
        if not os.path.exists(db_path):
            print("✅ Base de datos no encontrada, será creada automáticamente")
            return
        
        # Verificar si necesitamos hacer migraciones
        import sqlite3
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()
        
        # Verificar si las columnas ya existen
        cursor.execute("PRAGMA table_info(sent_email)")
        columns = cursor.fetchall()
        column_names = [column[1] for column in columns]
        
        # Añadir columna user_email si no existe
        if 'user_email' not in column_names:
            print("ℹ️ Añadiendo columna user_email a la base de datos")
            cursor.execute("ALTER TABLE sent_email ADD COLUMN user_email TEXT")
            
            # Actualizar user_email con el correo del usuario basado en user_id
            cursor.execute("""
                UPDATE sent_email 
                SET user_email = (
                    SELECT email FROM user WHERE user.id = sent_email.user_id
                )
            """)
            print("✅ Columna user_email añadida y actualizada")
        
        # Añadir columna template_id si no existe
        if 'template_id' not in column_names:
            print("ℹ️ Añadiendo columna template_id a la base de datos")
            cursor.execute("ALTER TABLE sent_email ADD COLUMN template_id TEXT DEFAULT 'custom'")
            print("✅ Columna template_id añadida")
        
        # Confirmar cambios y cerrar la conexión
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"❌ Error durante la migración de la base de datos: {str(e)}")

# Rutas para la autenticación
@app.route('/register', methods=['GET', 'POST'])
def register():
    if current_user.is_authenticated:
        return redirect(url_for('send_email'))
        
    if request.method == 'POST':
        email = request.form['email']
        password = request.form['password']
        name = request.form['name']
        company = request.form['company']
        
        # Validar el correo electrónico
        try:
            valid = validate_email(email)
            email = valid.email
        except EmailNotValidError as e:
            flash(f'Correo electrónico inválido: {str(e)}', 'danger')
            return render_template('register.html')
        
        # Verificar si el usuario ya existe
        existing_user = User.query.filter_by(email=email).first()
        if existing_user:
            flash('Este correo electrónico ya está registrado.', 'danger')
            return render_template('register.html')
        
        # Crear el nuevo usuario
        user = User(email=email, name=name, company=company)
        user.set_password(password)
        db.session.add(user)
        db.session.commit()
        
        flash('Registro exitoso. Ahora puedes iniciar sesión.', 'success')
        return redirect(url_for('login'))
        
    return render_template('register.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    if current_user.is_authenticated:
        return redirect(url_for('send_email'))
        
    if request.method == 'POST':
        email = request.form['email']
        password = request.form['password']
        
        user = User.query.filter_by(email=email).first()
        if user and user.check_password(password):
            login_user(user, remember=True)
            next_page = request.args.get('next')
            flash('Has iniciado sesión correctamente.', 'success')
            return redirect(next_page or url_for('send_email'))
        else:
            flash('Correo electrónico o contraseña incorrectos.', 'danger')
    
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    flash('Has cerrado sesión correctamente.', 'success')
    return redirect(url_for('login'))

@app.route('/profile')
@login_required
def profile():
    # Obtener el historial de correos enviados por el usuario
    try:
        # Primero intentar consultar con el esquema nuevo (con user_email)
        emails = SentEmail.query.filter_by(user_id=current_user.id).order_by(SentEmail.sent_at.desc()).all()
    except Exception as e:
        print(f"Error en profile: {e}")
        # Si falla, usar una consulta compatible con el esquema antiguo
        emails = db.session.query(
            SentEmail.id,
            SentEmail.user_id,
            SentEmail.sender,
            SentEmail.recipient,
            SentEmail.subject,
            SentEmail.body,
            SentEmail.status,
            SentEmail.sent_at
        ).filter(SentEmail.user_id == current_user.id).order_by(SentEmail.sent_at.desc()).all()
    
    return render_template('profile.html', emails=emails)

# Ruta para el auditlog global (solo administradores)
@app.route('/auditlog')
@login_required
def auditlog():
    # Verificar si el usuario actual es administrador
    if current_user.email != 'admin@dmarcdefense.com':
        flash('No tienes permisos para acceder a esta página', 'danger')
        return redirect(url_for('send_email'))
    
    try:
        # Intentar obtener los datos con el esquema nuevo
        all_emails = SentEmail.query.order_by(SentEmail.sent_at.desc()).all()
    except Exception as e:
        print(f"Error en auditlog: {e}")
        # Si falla, hacer una consulta compatible con el esquema antiguo
        all_emails = db.session.query(
            SentEmail.id, 
            SentEmail.user_id,
            SentEmail.sender, 
            SentEmail.recipient,
            SentEmail.subject,
            SentEmail.body,
            SentEmail.status,
            SentEmail.sent_at
        ).order_by(SentEmail.sent_at.desc()).all()
    
    # Obtener todos los usuarios para mostrar sus nombres
    users = User.query.all()
    user_dict = {user.id: user for user in users}
    
    return render_template('auditlog.html', emails=all_emails, users=user_dict, templates=TEMPLATES)

# Ruta para la página principal, ahora protegida con login_required
@app.route('/', methods=['GET', 'POST'])
@login_required
def send_email():
    if request.method == 'POST':
        sender = request.form['sender']
        subject_id = request.form['subject_id']
        recipient = request.form['recipient']
        body_text = request.form['custom_body']
        template_id = request.form.get('body_option', 'custom')  # Obtener la plantilla seleccionada
        attachments = []

        # Codificar body en Base64
        body_base64 = base64.b64encode(body_text.encode('utf-8')).decode('utf-8')

        # Procesar adjuntos si existen
        if 'attachments' in request.files:
            files = request.files.getlist('attachments')
            for file in files:
                if file.filename:
                    encoded_content = base64.b64encode(file.read()).decode('utf-8')
                    attachments.append({
                        "filename": file.filename,
                        "content_base64": encoded_content
                    })

        headers = {
            'Authorization': f'Token {API_TOKEN}',
            'Content-Type': 'application/json; charset=utf-8'
        }

        payload = {
            'sender': sender,
            'subject_id': subject_id,
            'recipient': recipient,
            'body': body_text,  
            'attachments': attachments
        }

        print("Payload enviado:", payload)

        try:
            response = requests.post(API_URL, json=payload, headers=headers)
            print("Código de respuesta:", response.status_code)
            print("Respuesta del servidor:", response.text)

            # Guardar el correo enviado en la base de datos
            try:
                # Intenta crear un registro con la estructura nueva
                email_record = SentEmail(
                    user_id=current_user.id,
                    user_email=current_user.email,
                    sender=sender,
                    recipient=recipient,
                    subject=subject_id,
                    body=body_text,
                    template_id=template_id,
                    status='success' if response.status_code == 200 else 'error'
                )
                db.session.add(email_record)
                db.session.commit()
            except Exception as db_error:
                print(f"Error al guardar con esquema nuevo: {db_error}")
                db.session.rollback()
                
                # Si falla, crear un registro compatible con la estructura antigua
                try:
                    email_record = SentEmail(
                        user_id=current_user.id,
                        sender=sender,
                        recipient=recipient,
                        subject=subject_id,
                        body=body_text,
                        status='success' if response.status_code == 200 else 'error'
                    )
                    db.session.add(email_record)
                    db.session.commit()
                except Exception as e:
                    print(f"Error crítico al guardar el correo: {e}")
                    db.session.rollback()

            if response.status_code == 200:
                return render_template('success.html')
            else:
                return render_template('error.html', error_message=response.text)
        except Exception as e:
            print("Error al hacer la solicitud:", e)
            
            # Registrar el error
            try:
                # Intenta crear un registro con la estructura nueva
                email_record = SentEmail(
                    user_id=current_user.id,
                    user_email=current_user.email,
                    sender=sender,
                    recipient=recipient,
                    subject=subject_id,
                    body=body_text,
                    template_id=template_id,
                    status='error'
                )
                db.session.add(email_record)
                db.session.commit()
            except Exception as db_error:
                print(f"Error al guardar con esquema nuevo: {db_error}")
                db.session.rollback()
                
                # Si falla, crear un registro compatible con la estructura antigua
                try:
                    email_record = SentEmail(
                        user_id=current_user.id,
                        sender=sender,
                        recipient=recipient,
                        subject=subject_id,
                        body=body_text,
                        status='error'
                    )
                    db.session.add(email_record)
                    db.session.commit()
                except Exception as e:
                    print(f"Error crítico al guardar el error: {e}")
                    db.session.rollback()
            
            return render_template('error.html', error_message=str(e))

    return render_template('form.html', templates=TEMPLATES)

# Función para crear usuario administrador
def create_admin():
    admin_email = 'admin@dmarcdefense.com'
    admin_exists = User.query.filter_by(email=admin_email).first()
    
    if not admin_exists:
        print("✅ Creando usuario administrador...")
        admin = User(
            email=admin_email,
            name='Administrador',
            company='DMARCDefense',
            password_hash=generate_password_hash('admin123')
        )
        try:
            db.session.add(admin)
            db.session.commit()
            print("✅ Usuario administrador creado con éxito")
            print(f"   Email: {admin_email}")
            print(f"   Contraseña: admin123")
        except Exception as e:
            db.session.rollback()
            print(f"❌ Error al crear el administrador: {e}")
    else:
        print("ℹ️ El usuario administrador ya existe")

# Punto de entrada
if __name__ == '__main__':
    # Inicializar la base de datos y realizar migraciones
    with app.app_context():
        db.create_all()
        # Migrar la base de datos si es necesario
        migrate_database()
        # Crear usuario administrador
        create_admin()
    
    app.run(host='0.0.0.0', port=8000, debug=True)
