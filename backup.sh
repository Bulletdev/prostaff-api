#!/bin/sh

# Configurações
BACKUP_DIR="/backups"
TIMESTAMP=$(date +"%Y%m%d%H%M%S")
FILENAME="backup-$TIMESTAMP.sql.gz"
RETENTION_DAYS=7

echo "Iniciando backup do banco: $PGDATABASE..."

# Realiza o dump e comprime
pg_dump -h $PGHOST -U $PGUSER $PGDATABASE | gzip > $BACKUP_DIR/$FILENAME

if [ $? -eq 0 ]; then
  echo "Backup realizado com sucesso: $FILENAME"
  
  # Opcional: Enviar para S3 (precisa do aws-cli ou rclone instalado no container)
  # s3cmd put $BACKUP_DIR/$FILENAME s3://seu-bucket-hetzner/
  
  # Remove backups antigos (mais de 7 dias)
  find $BACKUP_DIR -type f -mtime +$RETENTION_DAYS -name "*.sql.gz" -exec rm {} \;
else
  echo "Erro ao realizar backup!"
  exit 1
fi

