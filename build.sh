#!/bin/sh

# Support environments with docker-machine
# For base linux users, 127.0.0.1 is fine, but w/ docker-machine we need to
# use the host ip instead. So we'll generate an over-ridden env file that
# will get passed/copied properly into the target servers
NAME=${DOCKER_MACHINE_NAME-empty}
IP=127.0.0.1
if [ "$NAME" = "empty" ]
then
  echo "DOCKER_MACHINE_NAME is not set. To avoid warning messages, you might set this to ''."
elif [ -n $NAME ]
then
  IP=$(docker-machine ip $NAME)
  if [ ! -f gameon.${NAME}env ]
  then
    echo "Creating new environment file gameon.${NAME}env to contain environment variable overrides.
This file will use the docker host ip address ($IP).
When the docker containers are up, use https://$IP/ to connect to the game."
    sed -e "s#127.\0.\0\.1#${IP}#g" gameon.env > gameon.${NAME}env
  fi
fi

# If the keystore directory doesn't exist, then we should generate
# the keystores we need for local signed JWTs to work
if [ ! -d keystore ]
then
  echo "Generating key stores using ${IP}"
  mkdir -p keystore
  keytool -genkey -alias default -storepass testOnlyKeystore -keypass testOnlyKeystore -keystore keystore/key.jks -keyalg RSA -sigalg SHA1withRSA -validity 365 -dname "CN=${IP},OU=unknown,O=unknown,L=unknown,ST=unknown,C=CA"
  keytool -export -alias default -storepass testOnlyKeystore -keypass testOnlyKeystore -keystore keystore/key.jks -file keystore/public.crt
  keytool -import -noprompt -alias default -storepass truststore -keypass truststore -keystore keystore/truststore.jks -file keystore/public.crt
  rm -f keystore/public.crt
fi

for SUBDIR in *
do
  if [ -d "${SUBDIR}" ] && [ -e "${SUBDIR}/build.gradle" ]
  then
    cd $SUBDIR
    ../gradlew build
    cd ..
  fi
done

echo "
If all of that went well, remember to re-spin your docker containers:
 docker-compose build
 docker-compose up

The game will be running at https://${IP}/ when you're all done."
