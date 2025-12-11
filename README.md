# Overview

Deploys a prototype OpenRoaming profile provisioning portal and RADIUS authentication server.

# External pre-requisites

- DNS record for authentication server (e.g. auth.crispyfi.com)
- DNS record for NAI realm (e.g. crispyfi.com)
- Entra ID Enterprise App for SAML SSO which returns UPN as sAMAccountName and samlUuid
- SMTP relay account (e.g. SMTP2Go)

# Deployment

## 1) Provision an Ubuntu 22.04 VM

## 2) Clone this repository

```
sudo su
cd /opt
git clone https://github.com/crispyfi/diamond.git
cd diamond
```

## 3) Create environment variables file and edit

```
cp .env.sample .env
vi .env
```

## 4) Customise portal settings

```
vi config/portal/SettingFixture.php
```

## 5) Copy required files

```
geoLiteDB/GeoLite2-City.mmdb
```

## 6) Run deployment script

```
cd /opt/diamond
chmod +x deploy.sh
./deploy.sh
```

## 7) Admin login

Login to https://\<yourdomain\>.com/dashboard

username: `admin@example.com`
password: `gnimaornepo`

You will be prompted to setup MFA upon first login.

Remember to update your email address and password immediately after logging in.

## 8) User login

Users may login at https://\<yourdomain\>.com and sign in using SAML.