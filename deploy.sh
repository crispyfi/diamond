#!/bin/bash

# Source environment variables
source .env

# Set variable for script running directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check whether script is being run as root
if [ "$EUID" -ne 0 ]
  then echo "You must run this script as root, you can either sudo the script directly or become root with a command such as 'sudo su'"
  exit
fi

# Install dependencies
apt-get update -y
apt-get install curl wget vim git python3 python3-pip certbot -y

if ! command -v docker &> /dev/null
then
    # Install Docker
    echo "Installing Docker"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
else
    echo "Docker is already installed. Skipping installation."
fi

# Update firewall rules
echo "Updating firewall rules"
for port in 80/tcp 443/tcp 1812/udp 1813/udp; do sudo ufw allow $port; done

# Replace placeholders in the FreeRADIUS SQL module file
echo "Updating FreeRADIUS config files"
sed -i "s/-RSQLUSER-/${MYSQL_RADIUS_USER}/g" $SCRIPT_DIR/config/freeradius/mods-available/sql
sed -i "s/-RSQLPASS-/${MYSQL_RADIUS_PASSWORD}/g" $SCRIPT_DIR/config/freeradius/mods-available/sql

# Replace placeholders in the FreeRADIUS clients config file
sed -i "s/-RSHAREDSECRET-/${RADIUS_SECRET}/g" $SCRIPT_DIR/config/freeradius/clients.conf

# Request certificate from LetsEncrypt
certbot certonly --standalone -d ${HOSTNAME} -d ${HOSTNAME} -m ${EMAIL_ADDRESS} --agree-tos --no-eff-email --rsa-key-size 2048

# copy certs to signing directory
echo "Copying certificates to staging directories"

cp /etc/letsencrypt/live/${HOSTNAME}/privkey.pem $SCRIPT_DIR/certs/signing/privkey.pem
cp /etc/letsencrypt/live/${HOSTNAME}/cert.pem $SCRIPT_DIR/certs/signing/cert.pem
cp /usr/share/ca-certificates/mozilla/ISRG_Root_X1.crt $SCRIPT_DIR/certs/signing/ca.pem
cp /etc/letsencrypt/live/${HOSTNAME}/fullchain.pem  $SCRIPT_DIR/certs/signing/fullchain.pem
chmod 644 $SCRIPT_DIR/certs/signing/privkey.pem

# copy certs to nginx web server directory
cp /etc/letsencrypt/live/${HOSTNAME}/privkey.pem $SCRIPT_DIR/certs/nginx/ssl.key
cp /etc/letsencrypt/live/${HOSTNAME}/fullchain.pem $SCRIPT_DIR/certs/nginx/ssl.crt

# copy certs to FreeRADIUS directory
cp /etc/letsencrypt/live/${HOSTNAME}/privkey.pem $SCRIPT_DIR/certs/freeradius/privkey.pem
cp /etc/letsencrypt/live/${HOSTNAME}/fullchain.pem $SCRIPT_DIR/certs/freeradius/cert.pem
chmod 644 $SCRIPT_DIR/certs/freeradius/privkey.pem

# Run Docker Compose
echo "Starting docker containers"

docker compose up -d

echo "Waiting for containers to deploy..."
sleep 30

# Execute post-deployment commands inside web container
echo "Running post-deployment tasks inside web container"
docker compose exec web bash -c "
    php bin/console doctrine:migrations:migrate --no-interaction &&
    php bin/console doctrine:fixtures:load --no-interaction &&
    php bin/console lexik:jwt:generate-keypair --no-interaction &&
    sed -i 's/use_attribute_friendly_name: true/use_attribute_friendly_name: false/g' /var/www/openroaming/config/packages/security.yaml
    php bin/console cache:clear
    chown -R www-data:www-data /var/www/openroaming/public/resources/uploaded/ &&
    cd tools &&
    sh generatePfxSigningKey.sh
"

# Execute post-deployment commands inside freeradius container
echo "Running post-deployment tasks inside freeradius container"
docker compose exec freeradius bash -c "
    chown freerad:freerad /etc/freeradius/certs/cert.pem &&
    chown freerad:freerad /etc/freeradius/certs/privkey.pem &&
    chmod 600 /etc/freeradius/certs/privkey.pem &&
    chmod 600 /etc/freeradius/certs/cert.pem
"