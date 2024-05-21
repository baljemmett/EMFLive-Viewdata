FROM verity.microwavepizza.co.uk/asterisk-backports:latest

RUN ln -s /run/secrets/pgpass ~/.pgpass && \
    ln -s /run/secrets/pg_service.conf ~/.pg_service.conf && \
    ln -fs /run/secrets/odbc.ini /etc/odbc.ini

COPY asterisk-config/* /etc/asterisk/
COPY service.lua remindercalls_func_odbc.ini despatch-reminders /opt/remindercalls/
COPY sound-files/pcm /usr/share/asterisk/sounds/reminder-call/

VOLUME /var/spool/asterisk /usr/share/asterisk/sounds/reminder-call
