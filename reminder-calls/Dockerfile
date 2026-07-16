FROM verity.microwavepizza.co.uk/asterisk-backports:latest

RUN ln -s /run/secrets/pg_service.conf ~/.pg_service.conf && \
    ln -s /run/secrets/password_emf-alrm /etc/asterisk && \
    ln -s /run/secrets/password_emf-alarm /etc/asterisk && \
    ln -s /run/secrets/password_emf-hydra /etc/asterisk && \
    ln -fs /run/secrets/odbc.ini /etc/odbc.ini

RUN apt-get -y update \
    && apt-get -y install \
        libdbi-perl \
        libdbd-pg-perl \
    && rm -rf /var/lib/apt/lists/*

COPY asterisk-config/* /etc/asterisk/
COPY service.lua hydration-service.lua remindercalls_func_odbc.ini despatch-reminders despatch-hydration-reminders /opt/remindercalls/
COPY sound-files/pcm /usr/share/asterisk/sounds/reminder-call/

VOLUME /var/spool/asterisk /usr/share/asterisk/sounds/reminder-call
