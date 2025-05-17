# Dockerfile - Versión producción optimizada

FROM python:3.11-slim

# Variables de entorno para no generar archivos .pyc ni buffering
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Crear el directorio de la app
WORKDIR /app

# Instalar dependencias básicas
RUN apt-get update && apt-get install -y curl && apt-get clean

# Copiar requirements primero (aprovechar cache de Docker)
COPY requirements.txt .

# Instalar paquetes Python necesarios
RUN pip install --no-cache-dir -r requirements.txt

# Copiar todo el código de la app
COPY . .

# Exponer el puerto en el que corre Flask
EXPOSE 8000

# Comando para iniciar la app
CMD ["python", "app.py"]
