# Scripts de sauvegarde et de restauration des stratégies 1 et 2 P10

##############################################################################################################
##############################################################################################################
##############################################################################################################

#!/bin/bash
# Script Stratégie 1 (Sauvegarde)
# version : 1.0
# auteur : Thomas PUYO
# date : 2024-03-05 (YYYY/MM/DD)

# Définir les répertoires source et de sauvegarde
SOURCE_DIRS="/home/omega/SITE /home/omega/RH /home/omega/TICKETS /home/omega/FICHIERS /home/omega/MAILS"
BACKUP_DIR="/home/omega/SAUVEGARDES_strategie1"
REMOTE_USER="omega"
REMOTE_IP="192.168.XXX.XXX"
RETENTION_DAYS=7
BACKUP_LOG_DIR="/home/omega/BACKUP_LOG"
BACKUP_LOG="${BACKUP_LOG_DIR}/backup_save_strat1.log"
ERROR_LOG="${BACKUP_LOG_DIR}/backup_errors_strat1_save.log"
CURRENT_DATE=$(date +%Y-%m-%d_%H-%M)

# Vérifier si le répertoire de sauvegarde existe, sinon le créer sur le serveur distant
ssh "${REMOTE_USER}@${REMOTE_IP}" "[ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR}" 2>> ${ERROR_LOG}

# Vérifier si le répertoire du journal de sauvegarde existe, sinon le créer sur le serveur local
[ ! -d ${BACKUP_LOG_DIR} ] && mkdir -p ${BACKUP_LOG_DIR} 2>> ${ERROR_LOG}

# Vérifier si le fichier de journal de sauvegarde existe, sinon le créer sur le serveur distant
[ ! -f ${BACKUP_LOG} ] && touch ${BACKUP_LOG} 2>> ${ERROR_LOG}

# Vérifier si le fichier last_backup_date.txt existe, sinon le créer
ssh "${REMOTE_USER}@${REMOTE_IP}" "[ ! -f ${BACKUP_DIR}/last_backup_date.txt ] && touch ${BACKUP_DIR}/last_backup_date.txt" 2>> ${ERROR_LOG}

# Lire la date de la dernière sauvegarde
LAST_BACKUP_DATE=$(ssh ${REMOTE_USER}@${REMOTE_IP} cat ${BACKUP_DIR}/last_backup_date.txt) 2>> ${ERROR_LOG}

# Créer un nouveau répertoire de sauvegarde avec la date actuelle
NEW_BACKUP_DIR="${BACKUP_DIR}/Save_${CURRENT_DATE}"
ssh ${REMOTE_USER}@${REMOTE_IP} mkdir -p ${NEW_BACKUP_DIR} 2>> ${ERROR_LOG}

# Effectuer la sauvegarde incrémentale avec rsync et enregistrer les détails dans le fichier de journal
echo "$(date +%Y-%m-%d_%H-%M): Début du processus de sauvegarde de la stratégie 1" >> ${BACKUP_LOG} 2>> ${ERROR_LOG}
rsync -av --delete --link-dest=${BACKUP_DIR}/Save_${LAST_BACKUP_DATE} ${SOURCE_DIRS} ${REMOTE_USER}@${REMOTE_IP}:${NEW_BACKUP_DIR} 2>> ${ERROR_LOG}
echo "$(date +%Y-%m-%d_%H-%M): Fin du processus de sauvegarde de la stratégie 1" >> ${BACKUP_LOG} 2>> ${ERROR_LOG}

# Enregistrer la date de la sauvegarde actuelle sur le serveur distant
ssh "${REMOTE_USER}@${REMOTE_IP}" "echo ${CURRENT_DATE} > ${BACKUP_DIR}/last_backup_date.txt" 2>> ${ERROR_LOG}

# Supprimer les anciennes sauvegardes qui dépassent le nombre de jours de rétention sur le serveur distant
ssh "${REMOTE_USER}@${REMOTE_IP}" "find ${BACKUP_DIR} -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \;" 2>> ${ERROR_LOG}

##############################################################################################################
##############################################################################################################
##############################################################################################################

#!/bin/bash
# Script Stratégie 1 (Restauration)
# version : 1.0
# auteur : Thomas PUYO
# date : 2024-03-05 (YYYY/MM/DD)

# Définir le répertoire de sauvegarde
BACKUP_DIR="/home/omega/SAUVEGARDES_strategie1"
REMOTE_USER="omega"
REMOTE_IP="192.168.XXX.XXX"
BACKUP_LOG="/home/omega/BACKUP_LOG/backup_rest_strat1.log"
ERROR_LOG="/home/omega/BACKUP_LOG/backup_errors_strat1_rest.log"

# Lire les dates des deux dernières sauvegardes
LAST_BACKUP_DATE=$(ssh ${REMOTE_USER}@${REMOTE_IP} ls -1 ${BACKUP_DIR} | grep Save_ | tail -1 | awk -F'Save_' '{print $2}')
PREVIOUS_BACKUP_DATE=$(ssh ${REMOTE_USER}@${REMOTE_IP} ls -1 ${BACKUP_DIR} | grep Save_ | tail -2 | head -1 | awk -F'Save_' '{print $2}')

# Demander à l'utilisateur quelle version de la sauvegarde il veut restaurer
echo "Quelle version de la sauvegarde (Stratégie 1) voulez-vous restaurer ?"
echo "1. La sauvegarde du ${PREVIOUS_BACKUP_DATE} (n-1)"
echo "2. La sauvegarde du ${LAST_BACKUP_DATE} (n)"
read -p "Votre choix (1-2) : " VERSION

# Déterminer la date de la sauvegarde à restaurer
if [ "$VERSION" -eq 1 ]; then
    BACKUP_DATE=${PREVIOUS_BACKUP_DATE}
elif [ "$VERSION" -eq 2 ]; then
    BACKUP_DATE=${LAST_BACKUP_DATE}
else
    echo "Choix de version invalide."
    exit 1
fi

# Demander à utilisateur ce qu'il veut restaurer
echo "Que voulez-vous restaurer ?"
echo "1. Un fichier spécifique"
echo "2. Tous les fichiers"
read -p "Votre choix (1-2) : " CHOICE

# Vérifier si le fichier de journal de sauvegarde existe, sinon le créer sur le serveur local
[ ! -f ${BACKUP_LOG} ] && touch ${BACKUP_LOG} 2>>${ERROR_LOG}

# Restaurer un fichier spécifique
if [ "$CHOICE" -eq 1 ]; then
    read -p "Entrez le chemin du fichier à restaurer (exemple: /MAILS/Thomas) : " FILE_TO_RESTORE
    echo "$(date +%Y-%m-%d_%H-%M): Début de la restauration partielle de la stratégie 1" >> ${BACKUP_LOG} 2>>${ERROR_LOG}
    ssh ${REMOTE_USER}@${REMOTE_IP} "mkdir -p /home/omega/RESTAURATIONS_strategie1${FILE_TO_RESTORE%/*}" 2>>${ERROR_LOG}
    ssh ${REMOTE_USER}@${REMOTE_IP} "rsync -av ${BACKUP_DIR}/Save_${BACKUP_DATE}${FILE_TO_RESTORE} /home/omega/RESTAURATIONS_strategie1${FILE_TO_RESTORE}" 2>>${ERROR_LOG}
    echo "$(date +%Y-%m-%d_%H-%M): Fin de la restauration partielle de la stratégie 1" >> ${BACKUP_LOG} 2>>${ERROR_LOG}
    exit 0
fi

# Restaurer tous les fichiers
if [ "$CHOICE" -eq 2 ]; then
    echo "$(date +%Y-%m-%d_%H-%M): Début de la restauration complète de la stratégie 1" >> ${BACKUP_LOG} 2>>${ERROR_LOG}
    ssh ${REMOTE_USER}@${REMOTE_IP} "rsync -av ${BACKUP_DIR}/Save_${BACKUP_DATE}/ /home/omega/RESTAURATIONS_strategie1/" 2>>${ERROR_LOG}
    echo "$(date +%Y-%m-%d_%H-%M): Fin de la restauration complète de la stratégie 1" >> ${BACKUP_LOG} 2>>${ERROR_LOG}
    exit 0
fi

echo "Choix de restauration invalide."
echo "$(date +%Y-%m-%d_%H-%M): Choix invalide de l'utilisateur lors de la restauration de la stratégie 1" >> ${BACKUP_LOG} 2>>${ERROR_LOG}
exit 1

##############################################################################################################
##############################################################################################################
##############################################################################################################

#!/bin/bash
# Script Stratégie 2 (Sauvegarde)
# version : 1.0
# auteur : Thomas PUYO
# date : 2024-03-10 (YYYY/MM/DD)

# Définir le répertoire source et de sauvegarde
SOURCE_DIR="/home/omega/MACHINES"
BACKUP_DIR="/home/omega/SAUVEGARDES_strategie2"
REMOTE_USER="omega"
REMOTE_IP="192.168.XXX.XXX"
BACKUP_LOG_DIR="/home/omega/BACKUP_LOG"
BACKUP_LOG="${BACKUP_LOG_DIR}/backup_save_strat2.log"
ERROR_LOG="${BACKUP_LOG_DIR}/backup_errors_strat2_save.log"
CURRENT_DATE=$(date +%Y-%m-%d_%H-%M)
DAY_OF_WEEK=$(date +%u)
DAY_NAME=$(date +%A)
PREV_DAY=$(date -d "yesterday" +%A)

# Vérifier si le répertoire de sauvegarde existe, sinon le créer sur le serveur distant
ssh "${REMOTE_USER}@${REMOTE_IP}" "[ ! -d ${BACKUP_DIR} ] && mkdir -p ${BACKUP_DIR}" 2>> ${ERROR_LOG}

# Vérifier si le répertoire du journal de sauvegarde existe, sinon le créer sur le serveur local
[ ! -d ${BACKUP_LOG_DIR} ] && mkdir -p ${BACKUP_LOG_DIR} 2>> ${ERROR_LOG}

# Vérifier si le fichier de journal de sauvegarde existe, sinon le créer sur le serveur local
[ ! -f ${BACKUP_LOG} ] && touch ${BACKUP_LOG} 2>> ${ERROR_LOG}

# Vérifier si le fichier last_backup_date.txt existe, sinon le créer
ssh "${REMOTE_USER}@${REMOTE_IP}" "[ ! -f $BACKUP_DIR/last_backup_date.txt ] && touch $BACKUP_DIR/last_full_backup_date.txt" 2>> ${ERROR_LOG}

# Si c'est dimanche, effectuer une sauvegarde complète
if [ ${DAY_OF_WEEK} -eq 5 ]; then
    echo "$(date +%Y-%m-%d_%H-%M): Début de la sauvegarde complète de la stratégie 2" >> ${BACKUP_LOG}
    rsync -av --partial ${SOURCE_DIR} ${REMOTE_USER}@${REMOTE_IP}:${BACKUP_DIR}/Full_${CURRENT_DATE} 2>> ${ERROR_LOG}
    echo "$(date +%Y-%m-%d_%H-%M): Fin de la sauvegarde complète de la stratégie 2" >> ${BACKUP_LOG}
   # Enregistrer la date de la sauvegarde actuelle sur le serveur distant
    ssh "${REMOTE_USER}@${REMOTE_IP}" "echo ${CURRENT_DATE} > ${BACKUP_DIR}/last_full_backup_date.txt" 2>> ${ERROR_LOG}
else
    # Sinon, effectuer une sauvegarde différentielle
    LAST_FULL_BACKUP_DATE=$(ssh ${REMOTE_USER}@${REMOTE_IP} cat ${BACKUP_DIR}/last_full_backup_date.txt) 2>> ${ERROR_LOG}
    echo "$(date +%Y-%m-%d_%H-%M): Début de la sauvegarde différentielle de la stratégie 2" >> ${BACKUP_LOG}
    # Supprimer le répertoire incrémental de la veille s'il existe
    ssh "${REMOTE_USER}@${REMOTE_IP}" "[ -d ${BACKUP_DIR}/Save_${PREV_DAY} ] && rm -rf ${BACKUP_DIR}/Save_${PREV_DAY}" 2>> ${ERROR_LOG}
    rsync -av --partial --link-dest=${BACKUP_DIR}/Full_${LAST_FULL_BACKUP_DATE} ${SOURCE_DIR} ${REMOTE_USER}@${REMOTE_IP}:${BACKUP_DIR}/Save_${DAY_NAME} 2>> ${ERROR_LOG}
    echo "$(date +%Y-%m-%d_%H-%M): Fin de la sauvegarde différentielle de la stratégie 2" >> ${BACKUP_LOG}
fi

##############################################################################################################
##############################################################################################################
##############################################################################################################

#!/bin/bash
# Script Stratégie 2 (Restauration)
# version : 1.0
# auteur : Thomas PUYO
# date : 2024-03-10 (YYYY/MM/DD)

# Variables
REMOTE_USER="omega"
REMOTE_IP="192.168.XXX.XXX"
BACKUP_DIR="/home/omega/SAUVEGARDES_strategie2"
RESTORE_DIR="/home/omega/RESTAURATIONS_strategie2_choice"
BACKUP_LOG_DIR="/home/omega/BACKUP_LOG"
BACKUP_LOG="${BACKUP_LOG_DIR}/backup_rest_strat2.log"
ERROR_LOG="/home/omega/BACKUP_LOG/backup_errors_strat2_rest.log"
DAY_NAME=$(date +%A)

# Vérifier si le répertoire du journal de sauvegarde existe, sinon le créer sur le serveur local
[ ! -d ${BACKUP_LOG_DIR} ] && mkdir -p ${BACKUP_LOG_DIR} 2>> ${ERROR_LOG}

# Vérifier si le fichier de journal de sauvegarde existe, sinon le créer sur le serveur local
[ ! -f ${BACKUP_LOG} ] && touch ${BACKUP_LOG} 2>> ${ERROR_LOG}

# Obtenir la date de la dernière sauvegarde complète
LAST_FULL_BACKUP_DATE=$(ssh ${REMOTE_USER}@${REMOTE_IP} "cat ${BACKUP_DIR}/last_full_backup_date.txt") 2>> ${ERROR_LOG}

# Demander à utilisateur s'il souhaite restaurer la sauvegarde complète ou la dernière sauvegarde différentielle
echo "Voulez-vous restaurer la sauvegarde complète (c) ou la dernière sauvegarde différentielle (d) ?"
read -p "Entrez c ou d : " choice

if [ "$choice" = "c" ]; then
    # Restaurer la dernière sauvegarde complète
    echo "$(date +%Y-%m-%d_%H-%M): Début de la restauration complète de la stratégie 2" >> ${BACKUP_LOG}
    ssh ${REMOTE_USER}@${REMOTE_IP} "rsync -av ${BACKUP_DIR}/Full_${LAST_FULL_BACKUP_DATE} ${RESTORE_DIR}" 2>> ${ERROR_LOG}
    echo "$(date +%Y-%m-%d_%H-%M): Fin de la restauration complète de la stratégie 2" >> ${BACKUP_LOG}
elif [ "$choice" = "d" ]; then
    # Vérifier si une sauvegarde différentielle pour aujourd'hui existe
    if ssh ${REMOTE_USER}@${REMOTE_IP} "[ -d ${BACKUP_DIR}/Save_${DAY_NAME} ]" 2>> ${ERROR_LOG}; then
        # Si oui, restaurer la sauvegarde différentielle
        echo "$(date +%Y-%m-%d_%H-%M): Début de la restauration différentielle de la stratégie 2" >> ${BACKUP_LOG}
        ssh ${REMOTE_USER}@${REMOTE_IP} "rsync -av ${BACKUP_DIR}/Save_${DAY_NAME} ${RESTORE_DIR}" 2>> ${ERROR_LOG}
        echo "$(date +%Y-%m-%d_%H-%M): Fin de la restauration différentielle de la stratégie 2" >> ${BACKUP_LOG}
    else
        echo "Il n'y a pas de sauvegarde différentielle pour aujourd'hui."
    fi
else
    echo "Choix invalide."
    echo "$(date +%Y-%m-%d_%H-%M): Choix invalide lors de la restauration de la stratégie 2" >> ${BACKUP_LOG}
fi
