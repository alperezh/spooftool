# backup-scripts.tf

resource "local_file" "backup_script" {
  filename = "${path.module}/scripts/backup.sh"
  content = <<-EOT
#!/bin/bash

# Variables - Configuradas por Terraform
S3_BUCKET="${aws_s3_bucket.backups.id}"
DB_PATH="/app/instance/dmarcdefense.db"
BACKUP_DIR="/tmp/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
WEEKDAY=$(date +%u)
DAY_OF_MONTH=$(date +%d)
BACKUP_NAME="dmarcdefense_$TIMESTAMP.db"
LOG_FILE="$BACKUP_DIR/backup_log.txt"

# Crear directorio de backup
mkdir -p $BACKUP_DIR
echo "Iniciando backup: $TIMESTAMP" >> $LOG_FILE

# Comprobar si se puede acceder a la base de datos
if [ ! -f "$DB_PATH" ]; then
  echo "Error: Base de datos no encontrada en $DB_PATH" >> $LOG_FILE
  exit 1
fi

# Verificar si la base de datos está en uso
echo "Verificando que la base de datos no esté bloqueada..." >> $LOG_FILE
sqlite3 $DB_PATH "PRAGMA busy_timeout = 5000; PRAGMA journal_mode;"

# Crear respaldo usando sqlite3
echo "Creando backup usando sqlite3..." >> $LOG_FILE
DB_SIZE=$(du -h "$DB_PATH" | cut -f1)
echo "Tamaño de base de datos: $DB_SIZE" >> $LOG_FILE

sqlite3 $DB_PATH ".backup '$BACKUP_DIR/$BACKUP_NAME'"
if [ $? -ne 0 ]; then
  echo "Error al crear backup de la BD" >> $LOG_FILE
  exit 1
fi

# Comprimir el backup
echo "Comprimiendo backup..." >> $LOG_FILE
gzip -f "$BACKUP_DIR/$BACKUP_NAME"
BACKUP_FILE="$BACKUP_DIR/$BACKUP_NAME.gz"

# Verificar integridad
echo "Verificando integridad de la base de datos..." >> $LOG_FILE
INTEGRITY=$(sqlite3 $DB_PATH "PRAGMA integrity_check;")
echo "Resultado integridad: $INTEGRITY" >> $LOG_FILE

if [ "$INTEGRITY" != "ok" ]; then
  echo "ADVERTENCIA: La base de datos podría tener problemas de integridad" >> $LOG_FILE
fi

# Subir a S3
echo "Subiendo backup a S3..." >> $LOG_FILE

# Backup diario
aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/daily/$(date +%Y%m%d)_$BACKUP_NAME.gz"

# Backup semanal (lunes = 1)
if [ "$WEEKDAY" -eq "1" ]; then
  echo "Creando backup semanal..." >> $LOG_FILE
  aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/weekly/$(date +%Y%m%d)_$BACKUP_NAME.gz"
fi

# Backup mensual (día 1 del mes)
if [ "$DAY_OF_MONTH" -eq "01" ]; then
  echo "Creando backup mensual..." >> $LOG_FILE
  aws s3 cp "$BACKUP_FILE" "s3://$S3_BUCKET/monthly/$(date +%Y%m)_$BACKUP_NAME.gz"
fi

# Limpiar archivos temporales
rm -f "$BACKUP_FILE"
echo "Backup completado con éxito: $TIMESTAMP" >> $LOG_FILE
echo "Log de backup:" >> $LOG_FILE
cat $LOG_FILE

exit 0
EOT
}

resource "local_file" "restore_script" {
  filename = "${path.module}/scripts/restore.sh"
  content = <<-EOT
#!/bin/bash

# Variables - Configuradas por Terraform
S3_BUCKET="${aws_s3_bucket.backups.id}"
DB_PATH="/app/instance/dmarcdefense.db"
BACKUP_DIR="/tmp/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Verificar parámetros
if [ $# -lt 1 ]; then
  echo "Uso: $0 nombre_del_backup"
  echo "Ejemplo: $0 daily/20250120_dmarcdefense_20250120_030000.db.gz"
  
  # Listar backups disponibles
  echo "Backups diarios disponibles:"
  aws s3 ls "s3://$S3_BUCKET/daily/" | sort
  
  echo "Backups semanales disponibles:"
  aws s3 ls "s3://$S3_BUCKET/weekly/" | sort
  
  echo "Backups mensuales disponibles:"
  aws s3 ls "s3://$S3_BUCKET/monthly/" | sort
  
  exit 1
fi

BACKUP_KEY="$1"
RESTORE_DIR="$BACKUP_DIR/restore_$TIMESTAMP"
BACKUP_FILE=$(basename "$BACKUP_KEY")
RESTORE_FILE="$RESTORE_DIR/dmarcdefense.db"

# Crear directorio de restauración
mkdir -p "$RESTORE_DIR"

# Descargar backup de S3
echo "Descargando backup desde S3: $BACKUP_KEY"
aws s3 cp "s3://$S3_BUCKET/$BACKUP_KEY" "$RESTORE_DIR/$BACKUP_FILE"

if [ $? -ne 0 ]; then
  echo "Error: No se pudo descargar el backup desde S3"
  exit 1
fi

# Descomprimir backup
echo "Descomprimiendo backup..."
gunzip -f "$RESTORE_DIR/$BACKUP_FILE"
UNCOMPRESSED_FILE="${RESTORE_DIR}/${BACKUP_FILE%.gz}"

if [ ! -f "$UNCOMPRESSED_FILE" ]; then
  echo "Error: Falló la descompresión del backup"
  exit 1
fi

# Verificar integridad
echo "Verificando integridad del backup..."
INTEGRITY=$(sqlite3 "$UNCOMPRESSED_FILE" "PRAGMA integrity_check;")

if [ "$INTEGRITY" != "ok" ]; then
  echo "ADVERTENCIA: Posibles problemas de integridad en el backup"
  read -p "¿Desea continuar con la restauración? (s/n): " CONTINUE
  if [ "$CONTINUE" != "s" ]; then
    echo "Restauración cancelada por el usuario"
    exit 1
  fi
fi

# Hacer backup de la BD actual
echo "Haciendo backup de la base de datos actual..."
CURRENT_BACKUP="${BACKUP_DIR}/pre_restore_${TIMESTAMP}.db"
sqlite3 "$DB_PATH" ".backup '$CURRENT_BACKUP'"

# Detener el servicio
echo "Deteniendo el servicio para la restauración..."
# Comando para detener el servicio, ajustar según sistema
systemctl stop dmarcdefense || docker stop dmarcdefense || echo "ADVERTENCIA: No se pudo detener el servicio"

# Restaurar la base de datos
echo "Restaurando la base de datos..."
cp "$UNCOMPRESSED_FILE" "$DB_PATH"
chown -R www-data:www-data "$DB_PATH" || echo "Advertencia: No se pudo cambiar propietario del archivo"
chmod 644 "$DB_PATH"

# Iniciar el servicio
echo "Iniciando el servicio..."
# Comando para iniciar el servicio, ajustar según sistema
systemctl start dmarcdefense || docker start dmarcdefense || echo "ADVERTENCIA: No se pudo iniciar el servicio"

echo "Restauración completada con éxito"
echo "Backup previo guardado en: $CURRENT_BACKUP"
echo "Se restableció la base de datos desde: $BACKUP_KEY"

# Limpiar archivos temporales
rm -rf "$RESTORE_DIR"

exit 0
EOT
}

# Subir scripts a S3 para que estén disponibles
resource "aws_s3_object" "backup_script" {
  bucket = aws_s3_bucket.backups.id
  key    = "scripts/backup.sh"
  source = local_file.backup_script.filename
  etag   = filemd5(local_file.backup_script.filename)
}

resource "aws_s3_object" "restore_script" {
  bucket = aws_s3_bucket.backups.id
  key    = "scripts/restore.sh"
  source = local_file.restore_script.filename
  etag   = filemd5(local_file.restore_script.filename)
}
