#!/bin/sh

#############
### P5 OC ###
#############

# # # ETAPE 2 SERVEUR WEB APACHE # # # # # # # # # #

# installation Apache
apt update -y
apt install -y apache2

# récupération / extraction archives sites web
wget -qO- https://s3-eu-west-1.amazonaws.com/course.oc-static.com/projects/ASR_P5_Services_web_securises/extranet.rainbowbank.com.tar.gz | tar xvz -C /var/www
wget -qO- https://s3-eu-west-1.amazonaws.com/course.oc-static.com/projects/ASR_P5_Services_web_securises/admin.rainbowbank.com.tar.gz | tar xvz -C /var/www

# configuration du Vhost extranet
VHOST_CONF_EXTRANET="/etc/apache2/sites-available/extranet.rainbowbank.com.conf"

echo "<VirtualHost 192.168.XXX.XXX:80>
   ServerAdmin webmaster@extranet.rainbowbank.com
   ServerName extranet.rainbowbank.com

   # Réécriture HTTPS permanente
   RewriteEngine On
   RewriteCond %{HTTPS} !=on
   RewriteRule ^ https://%{HTTP_HOST}%{REQUEST_URI} [L,R=301]
</VirtualHost>

<VirtualHost 192.168.XXX.XXX:443>
   ServerAdmin webmaster@extranet.rainbowbank.com
   ServerName extranet.rainbowbank.com
   DocumentRoot /var/www/extranet.rainbowbank.com
   ErrorLog ${APACHE_LOG_DIR}/extranet-error.log
   CustomLog ${APACHE_LOG_DIR}/extranet-access.log combined

   # Config SSL
   SSLEngine on
   SSLCertificateFile /etc/ssl/certs/wildcard-cert.pem
   SSLCertificateKeyFile /etc/ssl/private/wildcard-key.pem
</VirtualHost>" > "$VHOST_CONF_EXTRANET"

echo "Le fichier de configuration Vhost a été créé : $VHOST_CONF_EXTRANET"

# configuration du Vhost admin
VHOST_CONF_ADMIN="/etc/apache2/sites-available/admin.rainbowbank.com.conf"

echo "<VirtualHost 150.10.XXX.XXX:5501>
    ServerAdmin webmaster@admin.rainbowbank.com
    ServerName admin.rainbowbank.com

    # Réécriture HTTPS permanente avec redirection de port
    RewriteEngine On
    RewriteCond %{HTTPS} off
    RewriteRule ^ https://150.10.XXX.XXX:5502%{REQUEST_URI} [L,R=301]
</VirtualHost>

<VirtualHost 150.10.XXX.XXX:5502>
    ServerAdmin webmaster@admin.rainbowbank.com
    ServerName admin.rainbowbank.com
    DocumentRoot /var/www/admin.rainbowbank.com
    ErrorLog \${APACHE_LOG_DIR}/admin-error.log
    CustomLog \${APACHE_LOG_DIR}/admin-access.log combined

    # Config SSL
    SSLEngine on
    SSLCertificateFile /etc/ssl/certs/wildcard-cert.pem
    SSLCertificateKeyFile /etc/ssl/private/wildcard-key.pem
</VirtualHost>" > "$VHOST_CONF_ADMIN"

echo "Le fichier de configuration Vhost Admin a été créé : $VHOST_CONF_ADMIN"

# activation du module Rewrite
a2enmod rewrite

# vérification apachectl configtest
result=$(apachectl configtest 2>&1)
echo "$result"

# dédfinition variables avec les informations nécessaires au certificat
COUNTRY="FR"
STATE="ILE DE FRANCE"
LOCALITY="PARIS"
ORGANIZATION="RAINBOW BANK"
ORG_UNIT="DIRECTION INFRASTRUCTURE ET LOGISTIQUE"
COMMON_NAME="*.adminrainbowbank.com"
EMAIL="admin@rainbowbankcom"

# création certificat auto-signé wildcard pour les 2 Vhosts avec
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout /etc/ssl/private/wildcard-key.pem \
    -out /etc/ssl/certs/wildcard-cert.pem \
    -subj "/C=$COUNTRY/ST=$STATE/L=$LOCALITY/O=$ORGANIZATION/OU=$ORG_UNIT/CN=$COMMON_NAME/emailAddress=$EMAIL"

# affichage d'un message de confirmation
echo "Certificat créé avec succès."

 # activation du module SSL
 a2enmod ssl

# attribution droits répertoires site web (également pour le FTP)
chown -R www-data:www-data /var/www/admin.rainbowbank.com
chown -R www-data:www-data /var/www/extranet.rainbowbank.com

chmod -R 575 /var/www/admin.rainbowbank.com
chmod -R 575 /var/www/extranet.rainbowbank.com

# modification du fichier ports.conf
sed -i '/<IfModule ssl_module>/a Listen 5502' /etc/apache2/ports.conf
sed -i '/<IfModule mod_gnutls.c>/a Listen 5502' /etc/apache2/ports.conf
sed -i '/Listen 80/a Listen 5501' /etc/apache2/ports.conf

# activation des 2 sites
cd /etc/apache2/sites-available
a2ensite admin.rainbowbank.com.conf
a2ensite extranet.rainbowbank.com.conf

# désactivation site par défault
cd /etc/apache2/sites-enabled
a2dissite 000-default.conf

# redémarrage
systemctl restart apache2

# # # ETAPE 3 FTP # # # # # # # # # # #

apt install -y vsftpd

# modification de vsftpd.conf

# déclaration de la variable
VSFTPD_CONF="/etc/vsftpd.conf"

# sauvegarde du fichier original
cp "$VSFTPD_CONF" "$VSFTPD_CONF.bak"

# remplacement des paramètres dans vsftpd.conf
sed -i 's/^listen=.*$/listen=YES/' "$VSFTPD_CONF"
sed -i 's/^listen_ipv6=.*$/listen_ipv6=NO/' "$VSFTPD_CONF"
sed -i 's/^anonymous_enable=.*$/anonymous_enable=NO/' "$VSFTPD_CONF"
sed -i 's/^local_enable=.*$/local_enable=YES/' "$VSFTPD_CONF"
sed -i 's/^dirmessage_enable=.*$/dirmessage_enable=YES/' "$VSFTPD_CONF"
sed -i 's/^use_localtime=.*$/use_localtime=YES/' "$VSFTPD_CONF"
sed -i 's/^xferlog_enable=.*$/xferlog_enable=YES/' "$VSFTPD_CONF"
sed -i 's/^connect_from_port_20=.*$/connect_from_port_20=YES/' "$VSFTPD_CONF"
sed -i 's|^secure_chroot_dir=.*$|secure_chroot_dir=/var/run/vsftpd/empty|' "$VSFTPD_CONF"
sed -i 's/^pam_service_name=.*$/pam_service_name=vsftpd/' "$VSFTPD_CONF"
sed -i 's|^rsa_cert_file=.*$|rsa_cert_file=/etc/ssl/certs/wildcard-cert.pem|' "$VSFTPD_CONF"
sed -i 's|^rsa_private_key_file=.*$|rsa_private_key_file=/etc/ssl/private/wildcard-key.pem|' "$VSFTPD_CONF"
sed -i 's/^ssl_enable=.*$/ssl_enable=YES/' "$VSFTPD_CONF"

# ajout des paramètres manquants
echo "listen_address=150.10.XXX.XXX" >> "$VSFTPD_CONF"
echo "pasv_enable=YES" >> "$VSFTPD_CONF"
echo "pasv_min_port=65435" >> "$VSFTPD_CONF"
echo "pasv_max_port=65535" >> "$VSFTPD_CONF"
echo "pasv_address=150.10.XXX.XXX" >> "$VSFTPD_CONF"
echo "chroot_local_user=YES" >> "$VSFTPD_CONF"
echo "allow_writeable_chroot=YES" >> "$VSFTPD_CONF"
echo "local_root=/var/www" >> "$VSFTPD_CONF"

# affichage d'un message de confirmation
echo "Les paramètres dans le fichier $VSFTPD_CONF ont été mis à jour."

# redémarrage de vsftpd
systemctl restart vsftpd

# création des utilisateurs et des groupes pour le FTP
adduser devuser
adduser graphicuser

addgroup developers
addgroup graphics
addgroup devgraph 

usermod -aG developers devuser
usermod -aG graphics graphicsuser
usermod -aG devgraph devuser
usermod -aG devgraph graphicuser

# modification des permissions (+ droits écriture PDF Extranet)
cd /var/www/extranet.rainbowbank.com
chown www-data:developers css js index.html
chown www-data:devgraph images
chmod 574 css/ images/ index.html js/
chmod 774 pdf/

cd /var/www/admin.rainbowbank.com
chown www-data:developers css js index.html
chown www-data:devgraph images
chmod 574 css/ images/ index.html js/ pdf/

# affichage d'un message de confirmation
echo "Les bonnes permissions pour les développeurs et les graphistes ont été attribuées."

# # # ETAPE 5 DDOS / FAIL2BAN # # # # # # # # # # #

# installation du Mod Evasive de Apache
apt install -y libapache2-mod-evasive

# modification et activation des paramètres dans le fichier evasive.conf
echo "<IfModule mod_evasive20.c>
  DOSHashTableSize 3097
  DOSPageCount 2
  DOSSiteCount 50
  DOSPageInterval 1
  DOSSiteInterval 1
  DOSBlockingPeriod 10
  DOSLogDir \"/var/log/apache2/mod_evasive\"
  #DOSEmailNotify      you@yourdomain.com
  DOSSystemCommand \"/bin/echo %s >> /var/log/apache2/mod_evasive/dos_evasive.log && /bin/date >> /var/log/apache2/mod_evasive/dos_evasive.log\"
  DOSWhitelist File:/etc/apache2/whitelist
</IfModule>" > "/etc/apache2/mods-available/evasive.conf"

# redémarrage de Apache
systemctl restart apache2

# affichage d'un message de confirmation
echo "Le Mod Evasive est prêt à l'emploi."

# # # # #

# installation de Fail2Ban
apt install -y fail2ban

# copie du fichier de config par defaut
cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local

# modification de la prison vsftpd
JAIL_LOCAL="/etc/fail2ban/jail.local"

# déclaration de la variable
JAIL_LOCAL="/etc/fail2ban/jail.local"

# insertion des 3 prisons (vsftpd / custom-test-all admin + extranet) dans jail.local
NEW_CONFIG="[vsftpd]
enabled = true
port = ftp,ftp-data,ftps,ftps-data
filter = vsftpd
logpath = /var/log/vsftpd.log
maxretry = 3
bantime = 300

[custom-test-all-extranet]
enabled  = true
filter   = custom-test-all
logpath  = /var/log/apache2/extranet-access.log
maxretry = 3
bantime  = 300

[custom-test-all-admin]
enabled  = true
filter   = custom-test-all
logpath  = /var/log/apache2/admin-access.log
maxretry = 3
bantime  = 300"

# suppression de la prison vsftpd d'origine
sed -i '/^\[vsftpd\]/,/^$/d' "$JAIL_LOCAL"

# ajout de la nouvelle config à la fin du fichier avec un espace
echo "\n$NEW_CONFIG" >> "$JAIL_LOCAL"

# # #

# nouvelle configuration pour la prison sshd (sinon fail2ban ne redémarre pas : enabled = true / backend = systemd)
SSHD_CONFIG="[sshd]
backend = systemd
enabled = true
port    = ssh
logpath = %(sshd_log)s"

# suppression de la prison sshd d'origine
sed -i '/^\[sshd\]/,/^$/d' "$JAIL_LOCAL"

# ajout de la nouvelle config à la fin du fichier avec un espace
echo "\n$SSHD_CONFIG" >> "$JAIL_LOCAL"

# # #

# création du filtre failregex
# Utiliser echo pour créer le fichier avec le contenu du filtre
echo "[Definition]\nfailregex = ^<HOST> -.*\"(GET|POST) /.+ HTTP/1\\.[01]\"\nignoreregex =" > "/etc/fail2ban/filter.d/custom-test-all.conf"

# redémarrage de Fail2Ban
systemctl restart fail2ban.service

# vérification que les prisons ont bien été créées
echo "Status de Fail2Ban :"
fail2ban-client status

# affichage d'un message de confirmation
echo "Fail2Ban est prêt à l'emploi."

# # # ETAPE 4 FILTRAGE IPTABLES # # # # # # # # # # #

apt install -y iptables

# ajout manuel des règles

# autorise le trafic SSH uniquement sur la patte interne
iptables -A INPUT -i ens36 -p tcp --dport 22 -j ACCEPT

# autorise le trafic HTTP depuis la patte externe vers le vhost extranet
iptables -A INPUT -i ens33 -p tcp --dport 80 -j ACCEPT
# autorise le trafic HTTPS depuis la patte externe vers le vhost extranet
iptables -A INPUT -i ens33 -p tcp --dport 443 -j ACCEPT
# autorise le trafic HTTP depuis la patte interne vers le vhost admin
iptables -A INPUT -i ens36 -p tcp --dport 5501 -j ACCEPT
# autorise le trafic HTTPS depuis la patte interne vers le vhost admin
iptables -A INPUT -i ens36 -p tcp --dport 5502 -j ACCEPT

# autorise le trafic FPT depuis la patte interne, port de contrôle et port de données
iptables -A INPUT -s 150.10.0.0/16 -d 150.10.0.XXX -i ens36 -p tcp --dport 20 -j ACCEPT
iptables -A INPUT -s 150.10.0.0/16 -d 150.10.0.XXX -i ens36 -p tcp --dport 21 -j ACCEPT
# autorise le trafic sur la plage de ports passifs depuis la patte interne
iptables -A INPUT -s 150.10.0.0/16 -d 150.10.0.XXX -i ens36 -p tcp --dport 65435:65535 -j ACCEPT

# autorise le trafic depuis la carte accès par pont pour conserver une connexion Internet
iptables -A INPUT -i ens37 -j ACCEPT

# blocage par défaut des paquets entrants
iptables -P INPUT DROP

# sauvegarde des règles
iptables-save > /etc/iptables.rules2

# affichage d'un message de confirmation
echo "Les règles de filtrage iptables ont été créées et sauvegardées."

# # # FIN DU SCRIPT # # # # # # # # # # #
echo "FIN DU SCRIPT"
