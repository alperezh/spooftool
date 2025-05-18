# Dockerfile para DMARCDefense
FROM python:3.11-slim

# Variables de entorno para no generar archivos .pyc ni buffering
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Crear el directorio de la app
WORKDIR /app

# Instalar dependencias básicas
RUN apt-get update && apt-get install -y curl && apt-get clean

# Copiar requirements.txt desde el directorio padre
# Nota el ../ que indica subir un nivel
COPY app/requirements.txt .

# Instalar paquetes Python necesarios
RUN pip install --no-cache-dir -r requirements.txt

# Copiar todo el código de la app
COPY app/ .

# Crear el directorio para la base de datos
RUN mkdir -p instance && chmod -R 777 instance

# Exponer el puerto en el que corre Flask
EXPOSE 8000

# Comando para iniciar la app
CMD ["python", "app.py"]
