######################################
### Fichiers config /scripts P8 OC ###
######################################

### Les sondes ###

# check_mysql_test
    #!/bin/bash

    # Informations de connexion à la base de donnees MariaDB
    DB_USER="adminwp"
    DB_PASSWORD="XXX"
    DB_HOST="localhost"

    # Commande pour verifier l'etat du serveur MariaDB
    MYSQLADMIN_CMD="mysqladmin -u$DB_USER -p$DB_PASSWORD -h $DB_HOST ping"

    # Commande pour capturer la sortie
    MYSQL_STATUS=$($MYSQLADMIN_CMD 2>&1)

    # Verification de la sortie pour determiner l'etat de la base de donnees
    if [[ "$MYSQL_STATUS" == "mysqld is alive" ]]; then
        echo "MARIADB OK - La base de données MariaDB est en cours d'exécution."
        exit 0
    else
        echo "CRITICAL - La base de données MariaDB n'est pas accessible. Erreur : $MYSQL_STATUS"
        exit 2
    fi

# check_session_test
    #!/bin/bash

    # Nom de l'utilisateur a verifier
    USER_TO_CHECK="nagios"

    # Commande pour recuperer les informations sur les sessions
    SESSION_INFO=$(who | grep -w "$USER_TO_CHECK")

    # Comptage du nombre de sessions pour l'utilisateur
    SESSION_COUNT=$(echo "$SESSION_INFO" | wc -l)

    # Definition du nombre attendu de sessions (dans ce cas, 1)
    EXPECTED_SESSION_COUNT=1

    # Verification du nombre de sessions et renvoi du statut approprie
    if [ "$SESSION_COUNT" -eq "$EXPECTED_SESSION_COUNT" ]; then
        echo "SESSION OK - Une seule session pour l'utilisateur $USER_TO_CHECK est ouverte."
        exit 0
    else
        echo "CRITICAL - Le nombre de sessions pour l'utilisateur $USER_TO_CHECK est incorrect. Sessions ouvertes : $SESSION_COUNT"
        exit 2
    fi

# check_index_test_nagios
    #!/bin/bash

    # URL de la page d'index du Serveur Nagios
    NAGIOS_URL="10.207.188.181/nagios4/main.php"

    # Utilisation de curl pour effectuer une requête HTTP sur la page d'index
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$NAGIOS_URL")

    # Definition du code de réponse attendu
    EXPECTED_RESPONSE=200

    # Vefication du code de réponse et renvoi du statut approprié
    if [ "$HTTP_RESPONSE" -eq "$EXPECTED_RESPONSE" ]; then
    echo "INDEX OK - La page d'index de Nagios est accessible ($NAGIOS_URL)"
    exit 0
    else
    echo "CRITICAL - La page d'index de Nagios n'est pas accessible ($NAGIOS_URL). Code de réponse : $HTTP_RESPONSE"
    exit 2
    fi

# check_index_test
    # #!/bin/bash

    # URL de la page d'index du site WordPress
    WORDPRESS_URL="10.207.188.154"

    # Utilisation de curl pour effectuer une requête HTTP sur la page d'index
    HTTP_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$WORDPRESS_URL")

    # Definition du code de réponse attendu
    EXPECTED_RESPONSE=200

    # Vefication du code de reponse et renvoi du statut approprie
    if [ "$HTTP_RESPONSE" -eq "$EXPECTED_RESPONSE" ]; then
        echo "INDEX OK - La page d'index de WordPress est accessible ($WORDPRESS_URL)"
        exit 0
    else
        echo "CRITICAL - La page d'index de WordPress n'est pas accessible ($WORDPRESS_URL). Code de réponse : $HTTP_RESPONSE"
        exit 2
    fi

### commands.cfg - rajouté à la fin ###

    ### WORDPRESS ###

    # PING
    define command{
                command_name check-ping-wp
                command_line /usr/lib/nagios/plugins/check_ping -H 10.XXX.XXX.XXX -w 40,40% -c 60,60%
    }

    # ESPACE DISQUE
    define command{
                command_name check-disk-wp
                command_line /usr/lib/nagios/plugins/check_by_ssh -H 10.XXX.XXX.XXX -C "/usr/lib/nagios/plugins/check_disk -w 70 -c 80 -p / -m" -l nagios6
    }

    # RAM
    define command{
                command_name check-memory-wp
                command_line /usr/lib/nagios/plugins/check_by_ssh -H 10.XXX.XXX.XXX -C "/usr/lib/nagios/plugins/check_memory -w 70% -c 85%" -l nagios6
    }

    # CPU
    define command{
                command_name check-load-wp
                command_line /usr/lib/nagios/plugins/check_by_ssh -H 10.XXX.XXX.XXX -C "/usr/lib/nagios/plugins/check_load -w 0.70,0.60,0.50 -c 0.90,0.80,0.70" -l nagios6
    }

    # INDEX PAGE
    define command{
                command_name check-index-wp
                command_line /usr/lib/nagios/plugins/check_by_ssh -H 10.XXX.XXX.XXX -C "/usr/lib/nagios/plugins/check_index_test" -l nagios6
    }

    # MARIADB
    define command{
                command_name check-mysql-wp
                command_line /usr/lib/nagios/plugins/check_by_ssh -H 10.XXX.XXX.XXX -C "/usr/lib/nagios/plugins/check_mysql_test" -l nagios6
    }

    # HTTP
    define command{
                command_name check-http-wp
                command_line /usr/lib/nagios/plugins/check_by_ssh -H 10.XXX.XXX.XXX -C "/usr/lib/nagios/plugins/check_http -H 10.XXX.XXX.XXX" -l nagios6
    }

    ### NAGIOS / LOCALHOST ###

    # PING
    define command{
                command_name check-ping-nagios
                command_line /usr/lib/nagios/plugins/check_ping -H 10.XXX.XXX.XXX -w 40,40% -c 60,60%
    }

    # SESSION
    define command{
                command_name check-session-nagios
                command_line /usr/lib/nagios/plugins/check_session_test
    }

    # CPU
    define command{
                command_name check-load-nagios
                command_line /usr/lib/nagios/plugins/check_load -w 0.70,0.60,0.50 -c 0.90,0.80,0.70
    }

    # INDEX PAGE
    define command{
                command_name check-index-nagios
                command_line /usr/lib/nagios/plugins/check_index_test_nagios
    }

    # ESPACE DISQUE
    define command{
                command_name check-disk-nagios
                command_line /usr/lib/nagios/plugins/check_disk -w 70 -c 80 -p / -m
    }

    # RAM
    define command{
                command_name check-memory-nagios
                command_line /usr/lib/nagios/plugins/check_memory -w 70% -c 85%
    }

    # HTTP
    define command{
                command_name check-http-nagios
                command_line /usr/lib/nagios/plugins/check_http -H 10.XXX.XXX.XXX
    }

### wordpress.cfg ###

    define host {
            #use                    mediasante-wordpress-host
            host_name               mediasante-wordpress
            alias                   mediasante-wp
            address                 10.XXX.XXX.XXX
            check_command           check-ping-wp
            check_interval          5
            retry_interval          1
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
            notification_options    d,u,r
    }

    define service {
            host_name               mediasante-wordpress
            service_description     DISK
            check_command           check-disk-wp
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
    }

    define service {
            host_name               mediasante-wordpress
            service_description     RAM
            check_command           check-memory-wp
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
    }

    define service {
            host_name               mediasante-wordpress
            service_description     CPU
            check_command           check-load-wp
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
    }

    define service {
            host_name               mediasante-wordpress
            service_description     INDEX PAGE
            check_command           check-index-wp
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
    }

    define service {
            host_name               mediasante-wordpress
            service_description     MARIADB
            check_command           check-mysql-wp
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
    }

    define service {
            host_name               mediasante-wordpress
            service_description     HTTP
            check_command           check-http-wp
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
    }

### nagioshost.cfg ###

    define host {
            #use                    mediasante-nagios-host
            host_name               mediasante-nagios
            alias                   mediasante-ng
            address                 10.XXX.XXX.XXX
            check_command           check-ping-nagios
            check_interval          5
            retry_interval          1
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
            notification_options    d,u,r
    }

    define service {
            host_name               mediasante-nagios
            service_description     SESSION
            check_command           check-session-nagios
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
    }

    define service {
            host_name               mediasante-nagios
            service_description     CPU
            check_command           check-load-nagios
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
    }

    define service {
            host_name               mediasante-nagios
            service_description     INDEX PAGE
            check_command           check-index-nagios
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
    }

    define service {
            host_name               mediasante-nagios
            service_description     DISK
            check_command           check-disk-nagios
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
    }

    define service {
            host_name               mediasante-nagios
            service_description     RAM
            check_command           check-memory-nagios
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
    }

    define service {
            host_name               mediasante-nagios
            service_description     HTTP
            check_command           check-http-nagios
            max_check_attempts      3
            contacts                nagiosadmin
            check_period            24x7
            notification_period     24x7
    }

### ajouté dans nagios.cfg ###

    cfg_file=/etc/nagios4/objects/wordpress.cfg
    cfg_file=/etc/nagios4/objects/nagioshost.cfg
# dans apache2.conf
        <Files "cmd.cgi">
            AuthDigestDomain "Nagios4"
            AuthDigestProvider file
            AuthUserFile    "/etc/nagios4/htdigest.users"
            AuthGroupFile   "/etc/group"
            AuthName        "Nagios4"
            AuthType        Digest
            Require         valid-user
            #Allow from     127.0.0.1 192.168.XXX.XXX
            #Require all    granted
            Require         valid-user
        </Files>
    </DirectoryMatch>
