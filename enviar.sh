#!/bin/bash

#ANO 2020

exec 1> >(logger -s -t $(basename $0)) 2>&1

#dados_copia.txt
D_COP=/programas/omsys/Connections/dados_copia.txt
CTL_RSYNC=/omcopia/controlersync.txt

if [ -e "$D_COP" ];then
 echo "/programas/omsys/Connections/dados_copia.txt  EXISTE"
 N_CLI=`cat /programas/omsys/Connections/dados_copia.txt | cut -f3 -d " " | tr '[:lower:]' '[:upper:]'`
else
 echo "/programas/omsys/Connections/dados_copia.txt NAO EXISTE"
 N_CLI=`cat /etc/sysconfig/network | grep HOSTNAME |cut -f 2 -d '='`
fi

if (ps aux | grep copia.sh | grep -v grep); then
 echo "executando copia, nao vai enviar"
 exit
elif (ps aux | grep rsync | grep -v grep);then
 echo "executando rsync, nao vai enviar"
 exit
else
 #verificar se ja enviou
 if [ ! -e $CTL_RSYNC ];then
  /usr/bin/rsync -he "ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p3123" -avr --exclude '*.log' --exclude '*.txt' --exclude '*.sql' --exclude '*.sh' /omcopia/  omsys.omsys.info:/externo/copias/
  if [ $? == 0 ];then
   touch $CTL_RSYNC
  else
   rm -fr $CTL_RSYNC 
  fi
 fi
fi
