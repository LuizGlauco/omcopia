#!/bin/bash

exec 1> >(logger -s -t $(basename $0)) 2>&1

#VARIAVEIS
TIMESTAMP=$(date +"%F")
MYSQL_USER="copia"
MYSQL=/usr/bin/mysql
MYSQLDUMP=/usr/bin/mysqldump

DIA=`date +%u`
DATA=`date +%Y%m%d`
HORA=`date +%H:%M`

seg="/omcopia/seg/"
ter="/omcopia/ter/"
qua="/omcopia/qua/"
qui="/omcopia/qui/"
sex="/omcopia/sex/"
sab="/omcopia/sab/"
dom="/omcopia/dom/"

#pasta copiadas
bkpdirmysql=("/var/lib/mysql")
cd /omcopia/

#remover arquivos antigos
rm -fr *.sql
rm -fr *.tmp
rm -fr /omcopia/controlersync.txt

#dados_copia.txt
D_COP=/programas/omsys/Connections/dados_copia.txt

if [ -e "$D_COP" ];then
 echo "dados_copia.txt Existe"
 N_CLI=`cat /programas/omsys/Connections/dados_copia.txt | cut -f3 -d " " | tr '[:lower:]' '[:upper:]'`
else
 echo "dados_copia.txt Arquivo NAO existe"
 N_CLI=`cat /etc/sysconfig/network | grep HOSTNAME |cut -f 2 -d '='`
fi

cd /omcopia/

INF="$N_CLI.txt"

echo "Executando Backup $DATA $HORA"

#GERANDO SQL DE CADA BASE
databases=`$MYSQL --user=$MYSQL_USER -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema|copia_seguranca)"`
if [ $? != 0 ];then
 echo "ERRO: Nao conectou com o mysql" 
 tar -cjf $N_CLI.bases.tar.bz2 ${bkpdirmysql[@]}
 echo "Copia mysql realizada por tar"
else
 $MYSQL --user=$MYSQL_USER -e "FLUSH LOGS;"
 
 for db in $databases; do
  echo "Copiando $db"
  $MYSQLDUMP --force --opt --single-transaction --no-autocommit --routines -u ${MYSQL_USER} --databases $db > "$db.sql"
   if [ $? != 0 ];then
    echo "ERRO na base: $db - COPIANDO por TAR"
    tar -cj /var/lib/mysql/$db >> $N_CLI.bases_erro.tar.bz2
   fi
 done

 #COMPACTANDO ARQUIVOS
 tar -cjf $N_CLI.bases.tar.bz2 *.sql *.bases_erro.tar.bz2
fi

if [ $(date +%d) == 01 ]; then
    echo "executando backup mensal"
    cp $N_CLI.bases.tar.bz2 $DATA.$N_CLI.bases.tar.bz2
fi

#deletar arquivos com mais de 1 ano
echo "Limpando arquivos > 365 dias..."
find /omcopia/* -maxdepth 1 -name '*.bz2' -mtime +365 -delete

#EXCLUINDO SQLS DEPOIS DE COMPACTADOS
rm -fr *.sql

#ARQUIVO DE CONTROLE TAR
#CONTROLE="/omcopia/incremental.txt"

#DIRETORIOS E ARQUIVOS QUE DEVEM SER FEITOS BACKUP
PASTAS="/omcopia/pastasbackup.txt"

#LOCAL ONDE SERA SALVO O BACKUP
LOCALBACKUP="/omcopia"

#ARQUIVO DE BASE PARA O FIND
CONTROLEFIND="/omcopia/diferencial"

if [ ! -e $CONTROLE ];then
 touch $CONTROLE
fi
if [ ! -e $PASTAS ];then
 echo "/programas/" > $PASTAS
 echo "/omsys-util/" >> $PASTAS

fi

completo()
{
tar -cjf $N_CLI.www.full.tar.bz2 -T $PASTAS --exclude=*.enc --exclude=*.rpm --exclude=*.pdf --exclude=*0.xml --exclude=*1.xml --exclude=*2.xml --exclude=*3.xml --exclude=*4.xml --exclude=*5.xml --exclude=*6.xml --exclude=*7.xml --exclude=*8.xml --exclude=*9.xml   --exclude=*.rec --exclude=/omcopia/*
touch -t `date +%Y%m%d%H%M`  $CONTROLEFIND
}

diferencial()
{
find `cat $PASTAS` \( -cnewer $CONTROLEFIND -a ! -type d \) >/omcopia/listadiferencial.txt
tar -cjf $N_CLI.www.dif.$DIA.tar.bz2 -T /omcopia/listadiferencial.txt  --exclude=*.enc --exclude=*.rpm --exclude=*.pdf --exclude=*0.xml --exclude=*1.xml --exclude=*2.xml --exclude=*3.xml --exclude=*4.xml --exclude=*5.xml --exclude=*6.xml --exclude=*7.xml --exclude=*8.xml --exclude=*9.xml   --exclude=*.rec --exclude=/omcopia/*
}

if [ $DIA == 6 ];then
 completo
elif [ ! -e $CONTROLEFIND ];then
  completo
 else
  ARQ1=$(find /omcopia/* -maxdepth 1 -name '*.full.tar.bz2' -mtime -7|wc -l)
  if [  $ARQ1 -eq 0 ]; then
   echo "FULL" 
   #APAGAR full mais antigos
   find /omcopia/* -maxdepth 1 -name '*.full.tar.bz2' -mtime +7 -delete
   completo
  else
   echo "DIF"
   diferencial
 fi
fi

if [ $DIA -eq 1 ]; then
    mv -f $N_CLI.www.*.tar.bz2 $N_CLI.bases.tar.bz2 $seg
elif  [ $DIA -eq 2 ]; then
    mv -f $N_CLI.www.*.tar.bz2 $N_CLI.bases.tar.bz2 $ter
elif  [ $DIA -eq 3 ]; then
    mv -f $N_CLI.www.*.tar.bz2 $N_CLI.bases.tar.bz2 $qua
elif  [ $DIA -eq 4 ]; then
    mv -f $N_CLI.www.*.tar.bz2 $N_CLI.bases.tar.bz2 $qui
elif  [ $DIA -eq 5 ]; then
    mv -f $N_CLI.www.*.tar.bz2 $N_CLI.bases.tar.bz2 $sex
elif  [ $DIA -eq 6 ]; then
    mv -f $N_CLI.www.*.tar.bz2 $N_CLI.bases.tar.bz2 $sab
elif  [ $DIA -eq 7 ]; then
    mv -f $N_CLI.www.*.tar.bz2 $N_CLI.bases.tar.bz2 $dom
fi

#COLOCAR A CADA 1 HORA EXECUTAR
if [ -L /etc/cron.hourly/0enviar ];then
 echo "Link existe"
else
 ln -s /omcopia/enviar.sh /etc/cron.hourly/0enviar
fi

#limpar rsyncs travados

killall -9 rsync

####DELETAR ARQUIVOS QUE NAO FAZEM MAIS COPIA
find /omcopia/* -maxdepth 1 -name '*.NFE.tar.bz2' -delete
find /omcopia/* -maxdepth 1 -name '*.www.tar.bz2' -delete

echo "Final da Copia"
