from flask import Flask, render_template, request
import requests
import base64

app = Flask(__name__)

API_URL = 'http://relay.dmarcd.net:5000/execute'
API_TOKEN = '006ed549912bc9d6c43c477242b1724103caa02b'

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



@app.route('/', methods=['GET', 'POST'])
def send_email():
    if request.method == 'POST':
        sender = request.form['sender']
        subject_id = request.form['subject_id']
        recipient = request.form['recipient']
        body_text = request.form['custom_body']
        attachments = []

        # 📎 Codificar body en Base64
        body_base64 = base64.b64encode(body_text.encode('utf-8')).decode('utf-8')

        # 📎 Procesar adjuntos si existen
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

            if response.status_code == 200:
                return render_template('success.html')
            else:
                return render_template('error.html', error_message=response.text)
        except Exception as e:
            print("Error al hacer la solicitud:", e)
            return render_template('error.html', error_message=str(e))

    return render_template('form.html', templates=TEMPLATES)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8000, debug=True)
